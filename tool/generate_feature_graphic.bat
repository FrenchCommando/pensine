@echo off
REM Converts the feature graphic SVG to PNG (1024x500) for Google Play Store.
REM Requires: npx (Node.js)

cd /d "%~dp0.."

echo Converting feature graphic SVG to PNG...
call npx --yes sharp-cli -i assets/feature_graphic.svg -o assets/feature_graphic.png resize 1024 500
if errorlevel 1 exit /b 1

echo Done! Output: assets/feature_graphic.png
