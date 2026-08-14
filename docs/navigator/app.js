"use strict";

const MANIFEST_URL = "navigation.tsv";
const REPOSITORY_URL = "https://github.com/wkx176617-sys/GIT";
const FEATURED_IDS = ["tutorial"];

const searchInput = document.querySelector("#search");
const clearButton = document.querySelector("#clear");
const categoriesElement = document.querySelector("#categories");
const resultsElement = document.querySelector("#results");
const emptyElement = document.querySelector("#empty");
const statusElement = document.querySelector("#status");
const titleElement = document.querySelector("#results-title");

let entries = [];
let visibleEntries = [];
let selectedCategory = "全部";
let hasChosenCategory = false;
let activeIndex = -1;

function parseManifest(text) {
  const rows = text.trim().split(/\r?\n/).map((row) => row.split("\t"));
  const headers = rows.shift();
  if (!headers || headers.length !== 8) throw new Error("导航索引格式不正确");
  return rows.map((columns) => {
    if (columns.length !== headers.length) throw new Error("导航索引存在损坏条目");
    return Object.fromEntries(headers.map((header, index) => [header, columns[index]]));
  });
}

function normalize(value) {
  return value.toLocaleLowerCase("zh-CN").replace(/[，。、“”‘’：；！？,.!?;:/\\()[\]{}_-]+/g, " ").replace(/\s+/g, " ").trim();
}

function scoreEntry(entry, query) {
  if (!query) return FEATURED_IDS.includes(entry.id) ? 100 - FEATURED_IDS.indexOf(entry.id) : 1;
  const terms = query.split(" ").filter(Boolean);
  const aliases = normalize(entry.keywords).split(" ").filter(Boolean);
  const title = normalize(entry.title);
  const summary = normalize(entry.summary);
  const category = normalize(entry.category);
  let score = 0;
  for (const term of terms) {
    if (title.includes(term)) score += 18;
    if (aliases.some((alias) => alias.includes(term) || term.includes(alias))) score += 12;
    if (summary.includes(term)) score += 7;
    if (category.includes(term)) score += 4;
  }
  return score;
}

function documentUrl(path) {
  return `${REPOSITORY_URL}/blob/main/${path}`;
}

function setActiveResult(index) {
  const cards = [...resultsElement.querySelectorAll(".result-card")];
  cards.forEach((card) => card.classList.remove("is-active"));
  if (!cards.length) {
    activeIndex = -1;
    return;
  }
  activeIndex = Math.max(0, Math.min(index, cards.length - 1));
  cards[activeIndex].classList.add("is-active");
  cards[activeIndex].scrollIntoView({ block: "nearest" });
}

function renderResults() {
  const query = normalize(searchInput.value);
  const source = entries.filter((entry) => !["home", "navigation"].includes(entry.id));
  visibleEntries = source
    .filter((entry) => selectedCategory === "全部" || entry.category === selectedCategory)
    .map((entry) => ({ ...entry, score: scoreEntry(entry, query) }))
    .filter((entry) => !query || entry.score > 0)
    .sort((left, right) => right.score - left.score || left.title.localeCompare(right.title, "zh-CN"));

  if (!query && selectedCategory === "全部" && !hasChosenCategory) {
    visibleEntries = visibleEntries.filter((entry) => FEATURED_IDS.includes(entry.id));
  }

  resultsElement.replaceChildren();
  for (const entry of visibleEntries) {
    const card = document.createElement("a");
    card.className = "result-card";
    card.href = documentUrl(entry.path);
    card.innerHTML = "<span class=\"result-category\"></span><span class=\"result-title\"></span><p class=\"result-summary\"></p><span class=\"result-action\">打开教程 →</span>";
    card.querySelector(".result-category").textContent = entry.category;
    card.querySelector(".result-title").textContent = entry.title;
    card.querySelector(".result-summary").textContent = entry.summary;
    resultsElement.append(card);
  }

  activeIndex = -1;
  emptyElement.hidden = visibleEntries.length !== 0;
  clearButton.hidden = searchInput.value.length === 0;
  titleElement.textContent = query || selectedCategory !== "全部" ? "搜索结果" : "从这里继续";
  statusElement.textContent = visibleEntries.length ? `${visibleEntries.length} 个入口` : "没有匹配结果";
}

function renderCategories() {
  const categories = ["全部", ...new Set(entries.filter((entry) => !["导航"].includes(entry.category)).map((entry) => entry.category))];
  categoriesElement.replaceChildren();
  for (const category of categories) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "category-button";
    button.textContent = category;
    button.setAttribute("aria-pressed", String(category === selectedCategory));
    button.addEventListener("click", () => {
      selectedCategory = category;
      hasChosenCategory = true;
      [...categoriesElement.children].forEach((item) => item.setAttribute("aria-pressed", String(item === button)));
      renderResults();
    });
    categoriesElement.append(button);
  }
}

searchInput.addEventListener("input", renderResults);
searchInput.addEventListener("keydown", (event) => {
  if (event.key === "ArrowDown") {
    event.preventDefault();
    setActiveResult(activeIndex + 1);
  } else if (event.key === "ArrowUp") {
    event.preventDefault();
    setActiveResult(activeIndex <= 0 ? visibleEntries.length - 1 : activeIndex - 1);
  } else if (event.key === "Enter" && activeIndex >= 0) {
    event.preventDefault();
    resultsElement.querySelectorAll(".result-card")[activeIndex]?.click();
  } else if (event.key === "Escape") {
    searchInput.value = "";
    renderResults();
  }
});

clearButton.addEventListener("click", () => {
  searchInput.value = "";
  searchInput.focus();
  renderResults();
});

fetch(MANIFEST_URL, { cache: "no-store" })
  .then((response) => {
    if (!response.ok) throw new Error(`索引读取失败：${response.status}`);
    return response.text();
  })
  .then((text) => {
    entries = parseManifest(text);
    renderCategories();
    renderResults();
  })
  .catch(() => {
    statusElement.textContent = "搜索索引暂时不可用";
    emptyElement.hidden = false;
    searchInput.disabled = true;
  });
