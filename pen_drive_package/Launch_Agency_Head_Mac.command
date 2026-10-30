#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PORT=8080

echo "==================================================="
echo "    STUDENT AGENCY MANAGER - MAC LAUNCHER"
echo "==================================================="
echo ""
echo "Starting local Agency Head Web App..."

# Check if port 8080 is in use, if so increment
while lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null ; do
    PORT=$((PORT+1))
done

cd "$DIR/Agency_Head_Web"
python3 -m http.server $PORT &
SERVER_PID=$!

sleep 1

# Open in Chrome app mode if installed, or default browser
if [ -d "/Applications/Google Chrome.app" ]; then
    open -na "Google Chrome" --args --app="http://localhost:$PORT/"
else
    open "http://localhost:$PORT/"
fi

echo "Agency Head is running at http://localhost:$PORT/"
echo "Press Ctrl+C in this terminal when finished to stop."

wait $SERVER_PID
