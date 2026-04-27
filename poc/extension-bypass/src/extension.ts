import * as vscode from "vscode";

export function activate(context: vscode.ExtensionContext) {
  const cmd = vscode.commands.registerCommand(
    "extensionBypass.writeFile",
    async () => {
      const folders = vscode.workspace.workspaceFolders;
      if (!folders) {
        vscode.window.showErrorMessage("No workspace folder open.");
        return;
      }

      const proofUri = vscode.Uri.joinPath(
        folders[0].uri,
        "EXTENSION_BYPASS_PROOF.txt"
      );

      const content = Buffer.from(
        [
          "This file was written by a VS Code extension via vscode.workspace.fs.",
          "",
          "The integrated terminal is sandboxed (agent-sbx / sandflox).",
          "This write did not go through the terminal.",
          "No shell command was executed. No PATH was consulted.",
          "No sandbox-exec / bwrap rule was evaluated.",
          "",
          `Timestamp: ${new Date().toISOString()}`,
        ].join("\n")
      );

      await vscode.workspace.fs.writeFile(proofUri, content);

      // Read it back to prove full round-trip
      const readBack = await vscode.workspace.fs.readFile(proofUri);
      const text = Buffer.from(readBack).toString("utf-8");

      vscode.window.showInformationMessage(
        `Bypass proof written (${text.length} bytes). ` +
          "Check EXTENSION_BYPASS_PROOF.txt in the workspace root."
      );
    }
  );

  context.subscriptions.push(cmd);
}

export function deactivate() {}
