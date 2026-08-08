local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

ls.add_snippets("c", {
  s("main", {
    t({ "int main(int argc, char *argv[]) {", "\t" }),
    i(1),
    t({ "", "\treturn 0;", "}" }),
  }),
  s("inc", {
    t("#include <"),
    i(1),
    t(">"),
  }),
  s("incl", {
    t('#include "'),
    i(1),
    t('"'),
  }),
  s("if", {
    t("if ("),
    i(1),
    t({ ") {", "\t" }),
    i(2),
    t({ "", "}" }),
  }),
  s("for", {
    t("for (int "),
    i(1, "i"),
    t(" = 0; "),
    i(2, "i"),
    t(" < "),
    i(3, "n"),
    t("; "),
    i(4, "i"),
    t({ "++) {", "\t" }),
    i(5),
    t({ "", "}" }),
  }),
  s("pf", {
    t('printf("'),
    i(1),
    t('\\n");'),
  }),
  s("pff", {
    t('printf("'),
    i(1),
    t('\\n", '),
    i(2),
    t(");"),
  }),
})
