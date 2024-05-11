# SPDX-FileCopyrightText: © 2024 Serhii Olendarenko
# SPDX-License-Identifier: MIT

use std log

use api.nu
use cdn.nu

def "markdownify richtext" [blocks: list<record>]: nothing -> string {
	$blocks | reduce --fold '' {|b, acc|
		let text = match $b.type {
			unstyled => $b.text
			_ => {
				log warning $"Unknown type of richtext block: ($b.type)"
				$b.text
			}
		}
		[$acc $text] | str join "\n"
	}
}

def "markdownify resources" [
	data: list<string>
	cell_path?: cell-path
	--hash-name
]: nothing -> string {
	log info $"\t($data | length) files"

	$data | reduce --fold '' {|it, acc|
		mkdir assets
		cd assets

		let cell_path = if $cell_path != null {
			$cell_path
		} else {
			[] | into cell-path
		}

		let resource = cdn download file --force ($it | get $cell_path)
		let final_name = if $hash_name {
			let hash = open --raw $resource | hash md5
			let ext = $resource | path parse | get extension
			let new_name = $"($hash).($ext)"
			mv --force $resource $new_name
			$new_name
		} else { $resource }

		log info "\t\tDone."

		[$acc $"![[assets/($final_name)]]"] | str join "\n"
	}
}

def "markdownify video" [
	qualities: list<record>
	thumbnail?: string
	--hash-name
]: nothing -> string {
	log info "\t1 video"

	let playlist = $qualities
		| where res != 'default'
		| sort-by --natural --reverse res
		| get 0.src

	mkdir assets
	cd assets

	let resource = cdn download video --force --cover $thumbnail $playlist
	let final_name = if $hash_name {
		let hash = open --raw $resource | hash md5
		let ext = $resource | path parse | get extension
		let new_name = $"($hash).($ext)"
		mv --force $resource $new_name
		$new_name
	} else { $resource }

	log info "\t\tDone."

	$"![[assets/($final_name)]]"
}

def "download exercise" [exercise: record] {
	let chapter = $exercise.chapter?
	let output_dir = if $chapter != null { $chapter.title } else { '.' }

	log info $'Downloading "($exercise.title)" to "($output_dir)"'

	mkdir $output_dir
	cd $output_dir

	let blocks = api exercise $exercise._id | get blocks
	$blocks | reduce --fold '' {|b, acc|
		let text = match $b.type {
			richtext => { markdownify richtext $b.meta_data.blocks },
			gallery => { markdownify resources --hash-name $b.data },
			image => { markdownify resources --hash-name [$b.data] },
			download => { markdownify resources $b.data ([src] | into cell-path) },
			video => { markdownify video --hash-name $b.qualities $b.meta_data.thumbnail? },
			_ => {
				log warning $"Unsupported block type: ($b.type). Skipping."
				''
			}
		}
		[$acc $text] | str join "\n"
	} | save --force $"($exercise.index + 1). ($exercise.title).md"
}

def "download course" [course?: record] {
	let pipe_in = $in
	let course = if $course == null { $pipe_in } else { $course }

	mkdir $course.title
	cd $course.title

	cdn download file --force $course.img poster

	$course.fullDescription | save --force README.md

	let chapters = $course.chapters | each {|it| api chapter $it._id}
	# Each chapter contains a list of exercises.
	# I create a reverse mapping here.
	let exercise_to_chapter = $chapters
		| select _id exercises._id
		| rename id exercises
		| each {|row|
			let chapter = $chapters | where _id == $row.id
			let chapter = if ($chapter | length) > 0 {
				$chapter | first | reject exercises
			} else {
				null
			}
			$row.exercises | each {|e|
				{_id: $e chapter: $chapter}
			}
		  }
		| flatten

	# And add a `chapter` column to the exercises table
	let exercises = $course.exercises | join --left $exercise_to_chapter _id | sort-by sort

	$exercises | enumerate | flatten | each {|e|
		download exercise $e
	}
}

export def main [
	base_url: string
	--login: string
	--password: string
] {
	{email: $login password: $password} | api login $base_url

	api purchases | each {|p|
		api course $p._id | download course
	}

	api logout
}
