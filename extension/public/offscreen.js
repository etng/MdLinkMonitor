const textArea = document.querySelector("#clipboard-target");

if (!textArea) {
  throw new Error("Offscreen clipboard target is missing");
}

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.target !== "offscreen" || message?.type !== "copy-text") {
    return undefined;
  }

  try {
    textArea.value = String(message.text ?? "");
    textArea.style.position = "fixed";
    textArea.style.top = "0";
    textArea.style.left = "-9999px";
    textArea.style.opacity = "0";
    textArea.focus();
    textArea.select();
    textArea.setSelectionRange(0, textArea.value.length);

    const copied = document.execCommand("copy");
    sendResponse({
      ok: copied,
      error: copied ? undefined : "document.execCommand(copy) returned false in offscreen document"
    });
  } catch (error) {
    sendResponse({
      ok: false,
      error: error instanceof Error ? error.message : String(error)
    });
  }

  return true;
});
