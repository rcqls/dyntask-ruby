## This file is in share/pandoc since it is saved in Github.
## How the different file works:
## 1) ~/.dyntask/etc/pandoc_extra_dir contains the location of DynTask.cfg_dir[:pandoc_extra]
## 2) DynTask.cfg_dir[:pandoc_extra] can be located:
## 		a) outside a docker machine (example: /dyndoc-library/pandoc-extra)
##  is located outside share/pandoc folder to be
## updated by the user. 
{
	"md2s5"			=> ["-t","s5","--webtex","-s","-V","s5-url=#{DynTask.cfg_pandoc[:extra_dir]}/s5-ui/default", "--self-contained"],
	"md2revealjs" 	=> ["-t","revealjs","--webtex","-s","-V","theme=sky","-V","revealjs-url=#{DynTask.cfg_pandoc[:extra_dir]}/reveal.js-3.1.0", "--self-contained"]
}
# --mathjax='https://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML'