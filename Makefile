#
# css/js minification/compression makefile
#

#
#   JS_TARGETS -- js files to minify/gzip
#   CSS_TARGETS -- css files to minify/gzip
#   CLEANUP -- additional files to delete during "make clean"
# 

JS_TARGETS = $(wildcard html/*.js)
CSS_TARGETS = $(wildcard html/*.css)
CLEANUP = $(wilcard _*)

# you can use a manifest file for targets, if that's more your style:
#CSS_TARGETS = $(shell cat manifest.txt)

# you can specify that your targets are generated by rules, and should be deleted during "make clean"
#CLEANUP = $(CSS_TARGETS) $(JS_TARGETS)

# google closure compiler needs every input script prefixed with --js=, as in --js=file1.js
#concatenated.min.js: file1.js file2.js
#   java -jar ~/bin/compiler.jar $(addprefix --js=,$^) >$@

#custom-concat.css: file1.css file2.css file3.css
#   cat $^ >$@

#######################################################
# you shouldn't need to edit anything below this line #
#######################################################

.DEFAULT_GOAL := all

all: js css

YUI = /usr/bin/yuicompressor

.PHONY: css js

# gz
# ---

%.gz: % ;    gzip -9 <$< >_`echo $@ | cut -c 6-`;   rm -f $(CSS_MINIFIED) $(CSS_GZIP) $(JS_GZIP) $(JS_MINIFIED)

# css
# ---

CSS_MINIFIED = $(CSS_TARGETS:.css=.min.css)
CSS_GZIP = $(CSS_TARGETS:.css=.css.gz)
CSS_MIN_GZIP = $(CSS_TARGETS:.css=.css.gz)

css: $(CSS_TARGETS) $(CSS_MINIFIED) $(CSS_GZIP) $(CSS_MIN_GZIP)

%.min.css: %.css;     $(YUI) $< | sed 's/ and(/ and (/g' >$@

# javascript
# ----------

JS_MINIFIED = $(JS_TARGETS:.js=.min.js)
JS_GZIP = $(JS_TARGETS:.js=.js.gz)
JS_MIN_GZIP = $(JS_TARGETS:.js=.js.gz)

js: $(JS_TARGETS) $(JS_MINIFIED) $(JS_GZIP) $(JS_MIN_GZIP)

%.min.js: %.js;     $(YUI) $< | sed 's/ and(/ and (/g' >$@

clean:;    rm -f $(CSS_MINIFIED) $(CSS_GZIP) $(CSS_MIN_GZIP) $(JS_GZIP) $(JS_MINIFIED) $(JS_MIN_GZIP) $(CLEANUP)
