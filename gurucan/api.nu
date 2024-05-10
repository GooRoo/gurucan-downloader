# SPDX-FileCopyrightText: © 2024 Serhii Olendarenko
# SPDX-License-Identifier: MIT

export def login [
	base_url: string
]: [nothing -> nothing, record -> nothing] {
	let credentials = $in
	let email = if $credentials.email? != null {
		$credentials.email
	} else {
		input "Enter email: "
	}
	let password = if $credentials.password? != null {
		$credentials.password
	} else {
		input --suppress-output "Enter password: "
	}

	const headers = {
		User-Agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
	}

	let payload = {
		email: $email
		password: $password
		nocookie: false
	}

	let url = [$base_url api users login] | path join
	let response = (
		http post
			--content-type application/json
			--headers $headers
			$url $payload
	)

	try { stor delete --table-name gurucan }
	stor create --table-name gurucan --columns {
		base_url: str, token: str
	}
	stor insert --table-name gurucan --data-record {
		base_url: $base_url, token: $response.jwt_token
	}

	null
}

export def logout [] {
	api users logout
	try { stor delete --table-name gurucan }
}

def "api get" [url?: string]: [nothing -> record, string -> record] {
	let url = if ($url != null) { $url } else { $in }

	let headers = {
		Cookie: $'jwt_token=(stor open | query db `SELECT token FROM gurucan` | get 0.token)'
		User-Agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
	}

	let response = http get --headers $headers $url
	if $response.status == 'ok' {
		$response
	} else {
		error make {msg: $"($response.code)"}
	}
}

def api [
	endpoint: string
	...params: string
	--query: record
] {
	let query_string = if $query != null {
		$query | url build-query
	} else {
		''
	}

	let base_name = (stor open | query db `SELECT base_url FROM gurucan` | get 0.base_url)
	[$base_name api $endpoint ...$params]
		| path join
		| [$in $query_string] | str join '?'
		| api get
}

export def me [] {
	api users me | get me
}

export def exercise [id: string] {
	api exercises $id | get exercise
}

export def purchases [] {
	let trash_cols = [
		tags
		isFree
		currency
		price
		sort
		exercisesAvailableWithoutProgress
		status
		productId
		ios_product_id
		android_product_id
		inAppId
		isPrivate
		coinPrice
		__v
		freeTasks
	]
	me | get purchasedItems._id | reject ...$trash_cols
}

export def course [id: string] {
	api courses $id --query {populate: 'true'} | get course
}

export def "course exercises" [id: string] {
	api courses $id exercises | get exercises
}

export def chapter [id: string] {
	api courses chapter $id | get chapter
}
