(async () => {
  const { endpoint, model } = await chrome.storage.sync.get({
    endpoint: "http://localhost:9090/ws",
    model: "small"
  });
  if (endpoint) document.getElementById("endpoint").value = endpoint;
  if (model) document.getElementById("model").value = model;
})();

document.getElementById("saveBtn").addEventListener("click", async () => {
  const endpoint = document.getElementById("endpoint").value.trim();
  const model = document.getElementById("model").value.trim() || "small";
  await chrome.storage.sync.set({ endpoint, model });
  alert("Settings saved.");
});