#!/data/data/com.termux/files/usr/bin/bash

# Check if yt-dlp is installed
if ! command -v yt-dlp &> /dev/null
then
    echo "yt-dlp could not be found. Please install it first."
    exit 1
fi

# Check if mpv is installed
if ! command -v mpv &> /dev/null
then
    echo "mpv could not be found. Please install it first."
    exit 1
fi

# Check if a channel URL is provided
if [ -z "$1" ]
then
    echo "Usage: $0 <YouTube Channel URL>"
    exit 1
fi

CHANNEL_URL="$1"

# Function to get random short videos from a general search
get_random_short_videos() {
    local search_query="short videos"
    local num_results=100 # Fetch up to 100 results to get a good pool

    # Use yt-dlp to search and get video info (URL and duration)
    # We select entries that have a URL and get their duration (default to 0 if not available)
    local search_info=$(yt-dlp --flat-playlist --print-json "ytsearch${num_results}:${search_query}" | jq -r '.entries[] | select(.url) | "\(.url) \(.duration // 0)"')

    local short_videos=""
    while IFS= read -r line; do
        local url=$(echo "$line" | awk '{print $1}')
        local duration=$(echo "$line" | awk '{print $2}')

        # Filter for videos between 60 and 120 seconds (1 to 2 minutes)
        if (( duration >= 60 && duration <= 120 )); then
            short_videos+="$url"$'\n'
        fi
    done <<< "$search_info"

    echo "$short_videos"
}

echo "Fetching random short videos for occasional playback..."
# Call the function to populate the short_distinct_video_array
SHORT_DISTINCT_VIDEO_URLS=$(get_random_short_videos)
IFS=$'\n' read -r -d '' -a short_distinct_video_array <<< "$SHORT_DISTINCT_VIDEO_URLS"

if (( ${#short_distinct_video_array[@]} == 0 )); then
    echo "Warning: Could not find any 1-2 minute distinct videos. Only main channel videos will be played."
fi

echo "Fetching video URLs from the main channel (including Shorts)..."
# Get a list of video URLs and their durations from the channel
# This command fetches all video URLs, including Shorts, as the jq filter no longer excludes them.
VIDEO_INFO=$(yt-dlp --flat-playlist --print-json "$CHANNEL_URL" | jq -r '.entries[] | select(.url) | "\(.url) \(.duration // 0)"')

ALL_VIDEO_URLS=""

while IFS= read -r line; do
    url=$(echo "$line" | awk '{print $1}')
    ALL_VIDEO_URLS+="$url"$'\n'
done <<< "$VIDEO_INFO"

# Check if any videos were found from the main channel
if [ -z "$ALL_VIDEO_URLS" ]
then
    echo "No videos found for the given channel URL. Exiting."
    exit 1
fi

# Convert the string of URLs into a bash array
IFS=$'\n' read -r -d '' -a all_video_array <<< "$ALL_VIDEO_URLS"

# Play videos in a loop
while true; do
    # Occasionally play a short, distinct video (1 in 5 chance)
    if (( ${#short_distinct_video_array[@]} > 0 )) && (( RANDOM % 5 == 0 )); then
        random_short_video=${short_distinct_video_array[$RANDOM % ${#short_distinct_video_array[@]}]}
        echo "Playing short distinct video: $random_short_video"
        mpv "$random_short_video"
        if [ $? -ne 0 ]; then
            echo "Error playing $random_short_video. Skipping..."
        fi
    else
        # Shuffle the main array for random playback
        shuffled_videos=($(shuf -e "${all_video_array[@]}"))

        for video_url in "${shuffled_videos[@]}"; do
            echo "Playing: $video_url"
            mpv "$video_url"
            if [ $? -ne 0 ]; then
                echo "Error playing $video_url. Skipping..."
            fi
        done
    fi
done