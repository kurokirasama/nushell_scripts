curl \
  'https://youtube.googleapis.com/youtube/v3/captions?part=snippet&videoId=MciOgsEOHZM&key=[YOUR_API_KEY]' \
  --header 'Authorization: Bearer [YOUR_ACCESS_TOKEN]' \
  --header 'Accept: application/json' \
  --compressed


curl -s \
  "https://youtube.googleapis.com/youtube/v3/captions/AUieDaZ6K80B9OIDb-tjZBNmkeM9RRv7mq3sLpVFfCcFSPt5?tfmt=srt&key=$AIzaSyBIAvg2lbYtlG8MvsjtVHV4eiqxhRdl598" \
  --header "Authorization: Bearer $token" \
  --header "Accept: application/json" \
  --compressed > "${video_id}.srt"




#video info
#with subtitle
let url = $"https://youtube.googleapis.com/youtube/v3/captions?part=snippet&videoId=MciOgsEOHZM&key=($api_key)"
let response = (http get $url)
let caption_list = ($response | get items | upsert language {|sn| $sn.snippet.language} | select id language)
let lan = "es"
let caption_id = (
  if ($caption_list | where language =~ $lan | is-empty) {
    $caption_list | where language =~ en | get id | get 0
  } else {
    $caption_list | where language =~ $lan | get id | get 0
  }
)
let caption_url = $"https://youtube.googleapis.com/youtube/v3/captions/($caption_id)?tfmt=srt&key=($api_key)"
let caption = (http get $caption_url)


#sans subtitle 
let url2 = $"https://youtube.googleapis.com/youtube/v3/captions?part=snippet&videoId=idUr_DRaZH4&key=($api_key)"
let response2 = (http get $url2)
let caption_list2 = ($response2 | get items | upsert language {|sn| $sn.snippet.language} | select id language)
let caption_id2 = (
  if ($caption_list2 | where language =~ $lan | is-empty) {
    $caption_list2 | where language =~ en | get id | get 0
  } else {
    $caption_list2 | where language =~ $lan | get id | get 0
  }
)


#español SpYAhgRHSyc
let url3 = $"https://youtube.googleapis.com/youtube/v3/captions?part=snippet&videoId=SpYAhgRHSyc&key=($api_key)"
let response3 = (http get $url)
let caption_list3 = ($response | get items | upsert language {|sn| $sn.snippet.language} | select id language)
let caption_id3 = (
  if ($caption_list3 | where language =~ $lan | is-empty) {
    $caption_list3 | where language =~ en | get id | get 0
  } else {
    $caption_list3 | where language =~ $lan | get id | get 0
  }
)



yt-dlp --write-sub --sub-lang es https://www.youtube.com/watch?v=MciOgsEOHZM


