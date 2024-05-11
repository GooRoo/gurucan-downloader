# SPDX-FileCopyrightText: © 2024 Serhii Olendarenko
# SPDX-License-Identifier: MIT

use std log

export def "download file" [
	url: string
	name?: string
	--force
]: nothing -> string {
	let file = $url | path parse
	let name = if ($name != null) { $name } else { $file.stem }
	let new_name = $"($name).($file.extension)"

	http get --raw $url | save --force=$force --raw $new_name
	$new_name
}

export def "download video" [
	url: string
	name?: string
	--cover: string
	--force
]: nothing -> string {
	let file = $url | path parse
	let name = if $name != null { $name } else { $file.stem }

	# All videos on the server are split. I need to download chunks
	# and to combine them.

	# So, I create a temporary subfolder for each video
	mkdir $name
	cd $name

	let videos = parse playlist $url
	$videos | par-each {|v|
		let fullUrl = $'https://cdn.gurucan.com/videos/($v.base)/($v.base)_($v.quality)-($v.name)'
		if $force or not ($v.name | path exists) {
			http get --raw $fullUrl | save --force=$force --raw $v.name
		}
	}

	let result = video combine $"($name)-nocover" | if $cover != null {
		video attach-cover $cover $name
	} else {
		mv $in $name
	}

	mv $result ../

	cd ..
	rm -rf $name

	$result
}

def "parse playlist" [url: string]: nothing -> table {
	let playlist = http get $url
	$playlist
		| lines
		| filter {|line| not ($line starts-with "#")}
		| parse "{base}_{quality}-{name}"
		| update quality 1080
}

def "video combine" [
	output_name: string
]: nothing -> string {
	ls *.ts
		| get name
		| each {|f| $"file '($f)'"}
		| save --force inputs.txt

	let output = $"($output_name).mp4"
	ffmpeg -f concat -hwaccel videotoolbox -safe 0 -i inputs.txt -c copy $output | complete | if $in.exit_code != 0 {
		log error $"Can't combine ($output)"
	}

	$output
}

def "video attach-cover" [
	cover_url
	output_name: string
]: string -> string {
	let input_video = $in
	let output = $"($output_name).mp4"

	if $cover_url != null {
		let image_file = download file --force $cover_url
		(ffmpeg
			-i $input_video -i $image_file
			-map 0 -map 1
			-c copy -c:v:1 mjpeg
			-disposition:v:1 attached_pic
			$output
		) | complete | if $in.exit_code != 0 {
			log error $"Can't attach cover to ($output)"
		}
	} else if $in != $output {
		mv $in $output
	}

	$output
}
