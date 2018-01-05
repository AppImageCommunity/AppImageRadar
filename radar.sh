#!/bin/bash

if [ -z "$GITHUB_TOKEN" ] ; then
  echo "\$GITHUB_TOKEN missing, please set it in the Travis CI settings of this project"
  echo "You can get one from https://github.com/settings/tokens"
  exit 1
fi

# rm repos.json
curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/search/code?sort=indexed&q=linuxdeployqt&page=1&per_page=100" > repos.json
curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/search/code?sort=indexed&q=AppImageKit&page=1&per_page=100" >> repos.json
# Find projects that have AppImage mentioned in their package.json
# since these possibly might offer an AppImage for download
for i in $(seq 1 5) ; do
  curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/search/code?sort=indexed&q=appimage+filename:package.json&page=$i&per_page=100" >> repos.json
done    

# Check whether the identified projects offer an 64-bit AppImage for download on GitHub Releases
# --> if yes, check whether the project is already mentioned on AppImageHub
#     --> if no, report it (or even create a PR for it)
# --> if no, check project's GitHub Issues for AppImage
#     --> if none exists, print URL to open one (or even open one)

RELEASES=$(cat repos.json | grep releases | cut -d '"' -f 4 | cut -d '{' -f 1)

for RELEASE in $RELEASES; do
  # echo $RELEASE
  APPIMAGES=$(curl -s -H "Authorization: token $GITHUB_TOKEN" $RELEASE | grep browser_download_url | grep -i '\.AppImage"' | grep 64 | cut -d '"' -f 4)
  APPIMAGE=$(echo "$APPIMAGES" | cut -d " " -f 1)
  SLUG=$(echo "$RELEASE" | cut -d  "/" -f 5-6)
  if [ ! -z "$APPIMAGE" ] ; then
    # echo $APPIMAGE # https://github.com/icewolfz/jiMUD/releases/download/0.4.28/jimud-0.4.28-x86_64.AppImage
    # Find out whether we have ANYTHING (code, PR, issue) in AppImageHub
    APPNAME=$(echo "$APPIMAGE" | cut -d "/" -f 9 | cut -d "_" -f 1 | cut -d "-" -f 1)
    CODE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/search/code?q=$APPNAME+repo:AppImage/appimage.github.io" | grep total_count | cut -d : -f 2 | cut -d " " -f 2 | cut -d "," -f 1)
    ISSUES=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/search/issues?q=$APPNAME+repo:AppImage/appimage.github.io" | grep total_count | cut -d : -f 2 | cut -d " " -f 2 | cut -d "," -f 1)
    # echo "# In AppImageHub: Code: $CODE, Issues: $ISSUES"
    if [ "$CODE" == "0" ] && [ "$ISSUES" == "0" ] ; then
      REPO=$(echo $APPIMAGE | cut -d  "/" -f 1-5)
      echo "$REPO"
    fi
  else
    # The project does not offer an AppImage for download
    # Find out whether we have a PR or issue in the project
    APPNAME=$(echo "$APPIMAGE" | cut -d "/" -f 9 | cut -d "_" -f 1 | cut -d "-" -f 1)
    ISSUES=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/search/issues?q=AppImage+repo:$SLUG" | grep total_count | cut -d : -f 2 | cut -d " " -f 2 | cut -d "," -f 1)
    # echo "# In $SLUG: Code: $CODE, Issues: $ISSUES"
    STARS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/$SLUG | grep stargazers_count | cut -d : -f 2 | cut -d " " -f 2 | cut -d "," -f 1)
    if [ $STARS -gt 1 ] ; then
      if [ "$ISSUES" == "0" ] ; then
        echo "https://github.com/$SLUG/issues/new # ($STARS stars)"
      else
        echo "https://github.com/$SLUG/search?q=AppImage&type=Issues # ($STARS stars)"
      fi
    else
      echo "# No AppImage but skipping https://github.com/$SLUG due to low star count ($STARS stars)"
    fi
  fi
done
