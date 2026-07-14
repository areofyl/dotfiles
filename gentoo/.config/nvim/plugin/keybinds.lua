vim.keymap.set("t", "<Esc>", "<C-\\><C-n>")

-- compile & run
vim.opt.makeprg = "cc %:S -o %:r:S"

vim.api.nvim_create_user_command("Mr", function()
  local has_makefile = vim.fn.filereadable("Makefile") == 1
  local cmd
  if has_makefile and vim.fn.system("grep -q '^run:' Makefile && echo y"):match("y") then
    cmd = "make run"
  else
    cmd = "./" .. vim.fn.expand("%:r")
  end
  vim.cmd("vertical botright split | term " .. cmd)
end, {})

-- markdown markup highlights (vague doesn't define these)
vim.api.nvim_set_hl(0, "@markup.italic", { italic = true })
vim.api.nvim_set_hl(0, "@markup.strong", { bold = true })
vim.api.nvim_set_hl(0, "@markup.strikethrough", { strikethrough = true })

-- title case helper (ignores small words unless first)
local small_words = {
  a=1, an=1, the=1, ["and"]=1, but=1, ["or"]=1, nor=1, ["for"]=1,
  yet=1, so=1, ["in"]=1, on=1, at=1, to=1, by=1, of=1, up=1,
  is=1, as=1, it=1, vs=1, via=1, per=1, ["if"]=1, ["do"]=1,
}

local function title_case(str)
  local words = {}
  for w in str:gmatch("%S+") do table.insert(words, w) end
  for i, w in ipairs(words) do
    if i == 1 or not small_words[w:lower()] then
      words[i] = w:sub(1,1):upper() .. w:sub(2)
    else
      words[i] = w:lower()
    end
  end
  return table.concat(words, " ")
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "en_us"
    vim.opt_local.spellcapcheck = ""
    vim.opt_local.conceallevel = 2

    -- tab/shift-tab to indent/unindent bullets
    vim.keymap.set("n", "<Tab>", ">>", { buffer = true })
    vim.keymap.set("n", "<S-Tab>", "<<", { buffer = true })
    vim.keymap.set("i", "<S-Tab>", "<C-d>", { buffer = true })

    -- title case headers on save
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = 0,
      callback = function()
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        for i, line in ipairs(lines) do
          local hashes, text = line:match("^(#+)%s+(.+)")
          if hashes and text then
            lines[i] = hashes .. " " .. title_case(text)
          end
        end
        vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      end,
    })
  end,
})

-- bio words for spellcheck
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    local words = {
      "allele", "alleles", "amino", "anaphase", "anticodon",
      "autosomal", "autosome", "autosomes",
      "bioflowers", "bioinformatics",
      "centromere", "centromeres", "chromatid", "chromatids",
      "chromatin", "chromosomal", "codon", "codons", "codominance",
      "codominant", "cytoplasm", "cytokinesis", "cytosine",
      "deoxyribonucleic", "diploid", "dihybrid",
      "endoplasmic", "eukaryote", "eukaryotes", "eukaryotic",
      "gamete", "gametes", "genotype", "genotypes", "genotypic",
      "glycolysis", "guanine",
      "haploid", "helicase", "hemizygous", "heterozygous",
      "homologous", "homozygous",
      "interphase",
      "karyotype", "karyotypes", "kinetochore",
      "locus", "loci", "lysosome", "lysosomes",
      "meiosis", "meiotic", "Mendel", "Mendelian",
      "metaphase", "mitochondria", "mitochondrion", "mitosis", "mitotic",
      "monohybrid", "mRNA", "tRNA", "rRNA",
      "nucleotide", "nucleotides", "nucleoplasm",
      "organelle", "organelles",
      "peptide", "peptides", "phenotype", "phenotypes", "phenotypic",
      "phospholipid", "phospholipids", "plasmid", "plasmids",
      "polymerase", "polypeptide", "polypeptides",
      "prokaryote", "prokaryotes", "prokaryotic",
      "prophase", "protease", "proteases", "Punnett",
      "recessive", "recombinant", "reticulum", "ribonucleic",
      "ribosome", "ribosomes",
      "spindle", "spliceosome",
      "telomere", "telomeres", "telophase", "thymine",
      "transcription", "translocation", "triploid",
      "uracil",
      "zygote", "zygotes", "zygosity",
    }
    for _, w in ipairs(words) do
      vim.cmd("silent! spellgood! " .. w)
    end
  end,
})
