set -e -x
hugo
cp public/index.xml public/atom.xml
cd public && git add * && git commit -a -m update && git push
