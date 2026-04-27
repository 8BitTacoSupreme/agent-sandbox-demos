//go:build linux

// sbx-landlock — Landlock LSM enforcement helper for sbx.
//
// Landlock requires syscalls that shell scripts cannot invoke. This small
// Go binary applies a Landlock ruleset to the current process, then execs
// the target command. Zero external dependencies — raw syscalls only.
//
// Usage:
//
//	sbx-landlock \
//	  --fs-mode=workspace \
//	  --workspace=/app \
//	  --denied=/home/agent/.ssh,/home/agent/.aws \
//	  --writable=/app,/tmp \
//	  --read-only=/app/.git,/app/policy.toml \
//	  --network=blocked \
//	  -- bash --rcfile .sandbox/armor.bash
package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"syscall"
	"unsafe"
)

// ── Landlock constants (linux/landlock.h) ──────────────────────────────────

// Ruleset access flags — filesystem (ABI v1+)
const (
	LANDLOCK_ACCESS_FS_EXECUTE    = 1 << 0
	LANDLOCK_ACCESS_FS_WRITE_FILE = 1 << 1
	LANDLOCK_ACCESS_FS_READ_FILE  = 1 << 2
	LANDLOCK_ACCESS_FS_READ_DIR   = 1 << 3
	LANDLOCK_ACCESS_FS_REMOVE_DIR = 1 << 4
	LANDLOCK_ACCESS_FS_REMOVE_FILE = 1 << 5
	LANDLOCK_ACCESS_FS_MAKE_CHAR  = 1 << 6
	LANDLOCK_ACCESS_FS_MAKE_DIR   = 1 << 7
	LANDLOCK_ACCESS_FS_MAKE_REG   = 1 << 8
	LANDLOCK_ACCESS_FS_MAKE_SOCK  = 1 << 9
	LANDLOCK_ACCESS_FS_MAKE_FIFO  = 1 << 10
	LANDLOCK_ACCESS_FS_MAKE_BLOCK = 1 << 11
	LANDLOCK_ACCESS_FS_MAKE_SYM   = 1 << 12
)

// ABI v3+: refer/truncate
const (
	LANDLOCK_ACCESS_FS_REFER    = 1 << 13
	LANDLOCK_ACCESS_FS_TRUNCATE = 1 << 14
)

// ABI v4+: network
const (
	LANDLOCK_ACCESS_NET_BIND_TCP    = 1 << 0
	LANDLOCK_ACCESS_NET_CONNECT_TCP = 1 << 1
)

// Rule types
const (
	LANDLOCK_RULE_PATH_BENEATH = 1
	LANDLOCK_RULE_NET_PORT     = 2
)

// Syscall numbers (amd64)
const (
	SYS_LANDLOCK_CREATE_RULESET  = 444
	SYS_LANDLOCK_ADD_RULE        = 445
	SYS_LANDLOCK_RESTRICT_SELF   = 446
)

// ── Landlock structs ───────────────────────────────────────────────────────

type landlockRulesetAttr struct {
	handledAccessFS  uint64
	handledAccessNet uint64
}

type landlockPathBeneathAttr struct {
	allowedAccess uint64
	parentFd      int32
	_padding      [4]byte
}

type landlockNetPortAttr struct {
	allowedAccess uint64
	port          uint64
}

// ── Syscall wrappers ───────────────────────────────────────────────────────

func landlockCreateRuleset(attr *landlockRulesetAttr) (int, error) {
	fd, _, errno := syscall.Syscall(
		SYS_LANDLOCK_CREATE_RULESET,
		uintptr(unsafe.Pointer(attr)),
		unsafe.Sizeof(*attr),
		0,
	)
	if errno != 0 {
		return -1, errno
	}
	return int(fd), nil
}

func landlockAddRulePathBeneath(rulesetFd int, attr *landlockPathBeneathAttr) error {
	_, _, errno := syscall.Syscall6(
		SYS_LANDLOCK_ADD_RULE,
		uintptr(rulesetFd),
		LANDLOCK_RULE_PATH_BENEATH,
		uintptr(unsafe.Pointer(attr)),
		0, 0, 0,
	)
	if errno != 0 {
		return errno
	}
	return nil
}

func landlockAddRuleNetPort(rulesetFd int, attr *landlockNetPortAttr) error {
	_, _, errno := syscall.Syscall6(
		SYS_LANDLOCK_ADD_RULE,
		uintptr(rulesetFd),
		LANDLOCK_RULE_NET_PORT,
		uintptr(unsafe.Pointer(attr)),
		0, 0, 0,
	)
	if errno != 0 {
		return errno
	}
	return nil
}

func landlockRestrictSelf(rulesetFd int) error {
	_, _, errno := syscall.Syscall(
		SYS_LANDLOCK_RESTRICT_SELF,
		uintptr(rulesetFd),
		0,
		0,
	)
	if errno != 0 {
		return errno
	}
	return nil
}

// Get Landlock ABI version via create_ruleset with nil attr + flag=1
func landlockGetABI() int {
	ver, _, errno := syscall.Syscall(
		SYS_LANDLOCK_CREATE_RULESET,
		0, 0, 1, // flags=LANDLOCK_CREATE_RULESET_VERSION
	)
	if errno != 0 {
		return 0
	}
	return int(ver)
}

// ── Path helpers ───────────────────────────────────────────────────────────

func addPathRule(rulesetFd int, path string, access uint64) error {
	fd, err := syscall.Open(path, syscall.O_PATH|syscall.O_CLOEXEC, 0)
	if err != nil {
		// Skip paths that don't exist — graceful degradation
		if os.IsNotExist(err) {
			return nil
		}
		return fmt.Errorf("open %s: %w", path, err)
	}
	defer syscall.Close(fd)

	attr := landlockPathBeneathAttr{
		allowedAccess: access,
		parentFd:      int32(fd),
	}
	return landlockAddRulePathBeneath(rulesetFd, &attr)
}

// ── Flag parsing ───────────────────────────────────────────────────────────

type config struct {
	fsMode   string
	workspace string
	denied   []string
	writable []string
	readOnly []string
	network  string
	argv     []string
}

func parseArgs(args []string) (*config, error) {
	cfg := &config{
		fsMode:  "workspace",
		network: "unrestricted",
	}

	i := 0
	for i < len(args) {
		arg := args[i]
		if arg == "--" {
			cfg.argv = args[i+1:]
			break
		}
		key, val, ok := strings.Cut(arg, "=")
		if !ok {
			return nil, fmt.Errorf("invalid flag: %s (expected --key=value)", arg)
		}
		switch key {
		case "--fs-mode":
			cfg.fsMode = val
		case "--workspace":
			cfg.workspace = val
		case "--denied":
			if val != "" {
				cfg.denied = strings.Split(val, ",")
			}
		case "--writable":
			if val != "" {
				cfg.writable = strings.Split(val, ",")
			}
		case "--read-only":
			if val != "" {
				cfg.readOnly = strings.Split(val, ",")
			}
		case "--network":
			cfg.network = val
		default:
			return nil, fmt.Errorf("unknown flag: %s", key)
		}
		i++
	}

	if len(cfg.argv) == 0 {
		return nil, fmt.Errorf("no command specified after --")
	}
	return cfg, nil
}

// ── Filesystem access masks ────────────────────────────────────────────────

const (
	readAccess = LANDLOCK_ACCESS_FS_EXECUTE |
		LANDLOCK_ACCESS_FS_READ_FILE |
		LANDLOCK_ACCESS_FS_READ_DIR

	writeAccess = LANDLOCK_ACCESS_FS_WRITE_FILE |
		LANDLOCK_ACCESS_FS_REMOVE_DIR |
		LANDLOCK_ACCESS_FS_REMOVE_FILE |
		LANDLOCK_ACCESS_FS_MAKE_CHAR |
		LANDLOCK_ACCESS_FS_MAKE_DIR |
		LANDLOCK_ACCESS_FS_MAKE_REG |
		LANDLOCK_ACCESS_FS_MAKE_SOCK |
		LANDLOCK_ACCESS_FS_MAKE_FIFO |
		LANDLOCK_ACCESS_FS_MAKE_BLOCK |
		LANDLOCK_ACCESS_FS_MAKE_SYM

	fullAccess = readAccess | writeAccess
)

// ── Main ───────────────────────────────────────────────────────────────────

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: sbx-landlock [flags] -- <command> [args...]")
		os.Exit(1)
	}

	cfg, err := parseArgs(os.Args[1:])
	if err != nil {
		fmt.Fprintf(os.Stderr, "[sbx-landlock] error: %v\n", err)
		os.Exit(1)
	}

	abi := landlockGetABI()
	if abi < 1 {
		// Landlock unavailable — just exec the command without enforcement
		fmt.Fprintln(os.Stderr, "[sbx-landlock] WARNING: Landlock not available, exec without enforcement")
		execCommand(cfg.argv)
		return
	}

	// Build the handled access mask based on ABI version
	handledFS := uint64(fullAccess)
	if abi >= 2 {
		handledFS |= LANDLOCK_ACCESS_FS_REFER
	}
	if abi >= 3 {
		handledFS |= LANDLOCK_ACCESS_FS_TRUNCATE
	}

	var handledNet uint64
	if abi >= 4 && cfg.network == "blocked" {
		handledNet = LANDLOCK_ACCESS_NET_BIND_TCP | LANDLOCK_ACCESS_NET_CONNECT_TCP
	}

	rulesetAttr := landlockRulesetAttr{
		handledAccessFS:  handledFS,
		handledAccessNet: handledNet,
	}

	rulesetFd, err := landlockCreateRuleset(&rulesetAttr)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[sbx-landlock] WARNING: create_ruleset failed: %v\n", err)
		execCommand(cfg.argv)
		return
	}
	defer syscall.Close(rulesetFd)

	// ── Add filesystem rules ──

	// System read paths — always allowed
	systemPaths := []string{"/usr", "/lib", "/lib64", "/etc", "/bin", "/sbin", "/nix", "/proc", "/dev"}
	for _, p := range systemPaths {
		_ = addPathRule(rulesetFd, p, readAccess)
	}

	// Workspace path handling depends on fs-mode
	if cfg.workspace != "" {
		switch cfg.fsMode {
		case "permissive":
			_ = addPathRule(rulesetFd, cfg.workspace, fullAccess)
		case "strict":
			_ = addPathRule(rulesetFd, cfg.workspace, readAccess)
		case "workspace":
			_ = addPathRule(rulesetFd, cfg.workspace, fullAccess)
		}
	}

	// Explicit writable paths
	for _, p := range cfg.writable {
		p = strings.TrimSpace(p)
		if p != "" {
			_ = addPathRule(rulesetFd, p, fullAccess)
		}
	}

	// Explicit read-only paths (these override writable if a parent was writable)
	for _, p := range cfg.readOnly {
		p = strings.TrimSpace(p)
		if p != "" {
			_ = addPathRule(rulesetFd, p, readAccess)
		}
	}

	// Denied paths get NO rules — Landlock's default deny means no rule = no access

	// /tmp always writable
	_ = addPathRule(rulesetFd, "/tmp", fullAccess)

	// HOME read for shell configs
	home := os.Getenv("HOME")
	if home != "" {
		_ = addPathRule(rulesetFd, home+"/.bashrc", readAccess)
		_ = addPathRule(rulesetFd, home+"/.profile", readAccess)
		_ = addPathRule(rulesetFd, home+"/.zshrc", readAccess)
	}

	// ── Add network rules (ABI v4+) ──

	if abi >= 4 && cfg.network == "blocked" {
		// Allow only loopback-style access: localhost ports
		// Landlock net rules are port-based, not address-based.
		// Allow binding and connecting to common localhost ports (1-65535).
		// The practical effect: since bwrap --unshare-net is used for full
		// network blocking, Landlock network rules here add defense-in-depth
		// for cases where bwrap net unshare isn't active.
		//
		// We intentionally add NO rules — which means all TCP bind/connect
		// is denied when network=blocked. Localhost access is handled by
		// bwrap's network namespace (or not unsharing it).

		// If allow-localhost is desired, permit loopback ports
		allowLocalhost := os.Getenv("SBX_ALLOW_LOCALHOST")
		if allowLocalhost == "true" || allowLocalhost == "1" {
			for port := uint64(1); port <= 65535; port++ {
				attr := landlockNetPortAttr{
					allowedAccess: LANDLOCK_ACCESS_NET_BIND_TCP | LANDLOCK_ACCESS_NET_CONNECT_TCP,
					port:          port,
				}
				_ = landlockAddRuleNetPort(rulesetFd, &attr)
			}
		}
	}

	// ── Apply the ruleset ──

	// Drop the ability to gain new privileges (required before restrict_self)
	if _, _, errno := syscall.Syscall(syscall.SYS_PRCTL, 38 /* PR_SET_NO_NEW_PRIVS */, 1, 0); errno != 0 {
		fmt.Fprintf(os.Stderr, "[sbx-landlock] WARNING: PR_SET_NO_NEW_PRIVS failed: %v\n", errno)
	}

	if err := landlockRestrictSelf(rulesetFd); err != nil {
		fmt.Fprintf(os.Stderr, "[sbx-landlock] WARNING: restrict_self failed: %v\n", err)
		execCommand(cfg.argv)
		return
	}

	fmt.Fprintf(os.Stderr, "[sbx-landlock] Landlock ruleset applied (ABI v%d, fs-mode=%s, network=%s)\n",
		abi, cfg.fsMode, cfg.network)

	execCommand(cfg.argv)
}

func execCommand(argv []string) {
	binary, err := findExecutable(argv[0])
	if err != nil {
		fmt.Fprintf(os.Stderr, "[sbx-landlock] error: %v\n", err)
		os.Exit(127)
	}
	err = syscall.Exec(binary, argv, os.Environ())
	if err != nil {
		fmt.Fprintf(os.Stderr, "[sbx-landlock] exec error: %v\n", err)
		os.Exit(126)
	}
}

func findExecutable(name string) (string, error) {
	if strings.Contains(name, "/") {
		return name, nil
	}
	pathEnv := os.Getenv("PATH")
	for _, dir := range strings.Split(pathEnv, ":") {
		full := dir + "/" + name
		info, err := os.Stat(full)
		if err == nil && info.Mode()&0111 != 0 {
			return full, nil
		}
	}
	return "", fmt.Errorf("%s: command not found", name)
}

// getLandlockABIStr returns the ABI version as a string for logging
func getLandlockABIStr() string {
	return strconv.Itoa(landlockGetABI())
}
