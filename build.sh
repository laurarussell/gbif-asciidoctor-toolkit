#!/bin/bash -e

# Run:
#   docker run --rm -it -v $PWD:/documents/ mb.gbif.org:5000/docker-asciidoctor:2.0.6

# Enable the **/*.$PRIMARY_LANGUAGE.adoc below.
shopt -s globstar
# In case there are no translations.
shopt -s nullglob

echo "Primary language is $PRIMARY_LANGUAGE."

# Check this is run from a reasonable directory.
# (Advanced users can run /bin/bash as a Docker target command.)
if [[ ! -e index.$PRIMARY_LANGUAGE.adoc ]]; then
    echo >&2 "There is no index.$PRIMARY_LANGUAGE.adoc file in this directory."
	echo >&2
	echo >&2 "Check you are running this from the top-level of your document,"
	echo >&2 "and that there is an $PRIMARY_LANGUAGE source document called index.$PRIMARY_LANGUAGE.adoc."
    exit 1
fi

# Clean any old files
echo "Cleaning old files"
git clean -f -x

# Produce the translated adoc source from the po-files.
if [[ -e po4a.conf ]]; then
	echo "Translating sources"
	po4a -v po4a.conf
	for lang in translations/??.po; do
		langcode=$(basename $lang .po)
		# Replace include and image links to translated alternatives
		for tdoc in $(grep -l -E -e '\.[a-z][a-z]\.adoc' **/*.$langcode.adoc); do
			echo "Replacing includes in $tdoc for $langcode"
			perl -pi -e 's/([A-Za-z0-9_-]+).'$PRIMARY_LANGUAGE'.adoc/\1.'$langcode'.adoc/' $tdoc
		done
	done
	echo "Translating source files completed"
else
	echo "No po4a.conf exists, this document will not be translated"
fi
echo

# Generate the output HTML and PDF.
rm -f **/*.??.html **/*.??.pdf *.??.asis
for lang in $PRIMARY_LANGUAGE translations/??.po; do
	langcode=$(basename $lang .po)
	echo "Building language $langcode"
	mkdir -p $langcode

	# Document title for PDF filename
	title=$(grep -m 1 '^=[^=]' index.$langcode.adoc | rev | cut -d: -f2- | rev | tr : - | tr / - | sed 's/^= *//; s/ /-/g; s/-+/-/g;' | tr '[:upper:]' '[:lower:]')
	echo "Document title in $langcode is “$title”"

	asciidoctor -a lang=$langcode \
				-a imagesdir=../ \
				-a pdf_filename=$title.$langcode.pdf \
				-r asciidoctor-diagram \
				-r /adoc/asciidoctor-extensions-lab/lib/git-metadata-preprocessor.rb \
				-r /adoc/gbif-extensions/lib/license-url-docinfoprocessor.rb \
				-r /adoc/gbif-extensions/lib/translation-links.rb \
				-r /adoc/GbifHtmlConverter.rb \
				-T /adoc/gbif-templates/ \
				-o $langcode/index.$langcode.html \
				--trace \
				index.$langcode.adoc


	asciidoctor-pdf -a lang=$langcode \
					-a media=print \
					-r asciidoctor-diagram \
					-r /adoc/asciidoctor-extensions-lab/lib/git-metadata-preprocessor.rb \
					-o $langcode/$title.$langcode.pdf \
					--trace \
					index.$langcode.adoc

	cat > index.$langcode.asis <<-EOF
		Status: 303 See Other
		Location: ./$langcode/
		Content-Type: text/html; charset=UTF-8
		Content-Language: $langcode
		Vary: negotiate,accept-language

		See <a href="./$langcode/">$langcode</a>.
	EOF

	echo "$langcode completed"
	echo
done

# Make translation template
# po4a-gettextize -f asciidoc -M utf-8 -m index.adoc -p translations/index.pot

# Update translation
# po4a-updatepo -f asciidoc -M utf-8 -m index.adoc -p translations/da.po

# po4a-normalize -f asciidoc -M utf-8 translations/da.po

# Translate
# po4a-translate -f asciidoc -M utf-8 -m index.adoc -p translations/da.po -k 0 -l index.da.adoc
