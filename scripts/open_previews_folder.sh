# Opens the screenshots of a ThreemaPreviewsTests run. The marker is written by `ScreenshotGenerator`
# and consumed here, so that any other test run of this scheme does nothing.
directory="$PROJECT_DIR/build/PreviewScreenshots"
marker="$directory/.generated"

if [ -f "$marker" ]; then
    rm -f "$marker"
    open "$directory"
fi
