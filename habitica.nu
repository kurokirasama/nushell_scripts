#habitipy dailies done all
export def "habitica mark-dailies-done" [] {
  let to_do = (
    habitipy dailies 
    | grep ✖ 
    | lines 
    | parse "{n}. ✖{rest}" 
    | get n 
    | into int
  )

  if not ($to_do | is-empty) {
    habitipy dailies done ...$to_do 
  }
}


#list habitica todos
export def "habitica ls" [
	--first(-f):int = 20
] {
	habitipy todos 
	| lines 
	| first $first 
	| parse "{idx}✖{todos}" 
	| reject idx 
	| str trim	
}