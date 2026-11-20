// The app's own words in English or Polish. Screens write English inside tr("…"); the
// Polish comes from data/ui-pl.json, which is made by tools/l10n/ui_pl.py and checked by
// tools/l10n/check_strings.py (it reads these files too). Same rules as the iPhone app.

let table = {};
export let lang = "en";

export function setLanguage(code, polishTable) {
  lang = code === "pl" ? "pl" : "en";
  table = lang === "pl" ? polishTable || {} : {};
  document.documentElement.lang = lang;
}

/** English in, the learner's language out; {0}, {1}… replaced by the values. */
export function tr(english, ...values) {
  let out = table[english] ?? english;
  values.forEach((v, i) => { out = out.split(`{${i}}`).join(String(v)); });
  return out;
}

/** "3 phrases" / "3 zwroty": a count with the right form of the noun. */
export function plural(n, one, other, pl) {
  if (lang === "pl" && pl) return `${n} ${polishForm(n, ...pl)}`;
  return `${n} ${n === 1 ? one : other}`;
}

export function polishForm(n, one, few, many) {
  const a = Math.abs(n);
  if (a === 1) return one;
  const last = a % 10, lastTwo = a % 100;
  if (last >= 2 && last <= 4 && !(lastTwo >= 12 && lastTwo <= 14)) return few;
  return many;
}

/** The browser's preferred language, if the learner hasn't chosen one. */
export function preferredLanguage() {
  const l = (navigator.languages && navigator.languages[0]) || navigator.language || "en";
  return l.toLowerCase().startsWith("pl") ? "pl" : "en";
}
