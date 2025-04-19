## Source https://github.com/nushell/nu_scripts/tree/main/maths ##

#Root with a custom denominator
export def "math root" [ denominator, num ] {
	$num ** ( 1 / $denominator ) | math round  -p 10
}

#Cube root
export def "math croot" [num] {
	$num ** ( 1 / 3 ) | math round -p 10
}

#Root with a custom scaler and denominator
export def "math aroot" [ scaler, denominator, num] {
	$num ** ($scaler / $denominator) | math round -p 10
}

#Factorial of the given number
export def "math fac" [num: int] {
	if $num < 0 {
		return-error 'Error: can only calculate non-negative integers'
	}
	if $num < 2 {
		$num
	} else {
		seq 2 $num | math product
	}
}

## Mine ##

#Calculate roots of the quadratic function: ax^2+bx+x
export def "math qroots" [
	a 	# x^2
	b	# x
	c 	# independent term
] {
	let d = $b ** 2 - 4 * $a * $c
	if $d >= 0 {
		let s = ($d | math sqrt)
		let r1 = (($s - $b) / (2 * $a))
		let r2 = (0 - (($s + $b) / (2 * $a)))
		
		return {root_1: $r1, root_2: $r2}
	} else {
		let s = ((0 - $d) | math sqrt)
		let r = ((0 - $b) / (2 * $a))
		let i = ($s / (2 * $a))

		return {root_1: $"($r) + ($i)*i", root_2: $"($r) - ($i)*i"}
	}
}

#Check if integer is prime
export def "math isprime" [n: int] {
	let max = $n | math sqrt | math ceil

	if $n == 1 or ($n mod 2) == 0 {
		return false
	} 
	if $n == 2 {
		return true
	} 

	for m in (seq 3 2 $max) {
		if ($n mod $m) == 0 { 
			return false 
		}
	}

	return true
}

#Prime list <= n
export def "math prime-list" [n: int] {
	let primes = [2 3]

	let primes2 = (seq 5 2 $n 
					| each {|it| 
						if (math isprime $it) {
							$it
						}
					}
				)

	return ($primes ++ $primes2)
}

#Multiplication table of n till max
export def "math mtable" [n: int, max: int] {
	seq 1 $max 
	| each {|it| 
		print ($"($it)*($n) = ($n * $it)")
	}
}

#Check if year is leap
export def isleap [year: int] {
	let div_4 = ($year mod 4) == 0
	let not_div_100 = ($year mod 100) != 0
	let div_400 = ($year mod 400) == 0

	if ($div_4 and $not_div_100) or $div_400 { 
		return true 
	} 
	return false
}

#Greatest common divisior (gcd) between 2 integers
export def "math gcd" [a: int, b:int] {
	if $a < $b { 
		return (math gcd $b $a )
	} 
	if $b == 0 { 
		return $a 
	} 

	return (math gcd $b ($a mod $b) )
}

#Least common multiple (lcm) between 2 integers
export def "math lcm" [a: int, b:int] {
	if $a == $b and $b == 0 {
		return 0
	} 

	$a * ($b / (math gcd $a $b))
}

#Decimal number to custom base representation
export def dec2base [
	number: int	#integer in decimal base
	base: int	#base in [2,16]
] {
	if $base < 2 or $base > 16 {
		return-error "Wrong base, it must be an integer between 2 and 16"
	} 

	let chars = ['0' '1' '2' '3' '4' '5' '6' '7' '8' '9' 'A' 'B' 'C' 'D' 'E' 'F']
	
	if $number == 0 { 
		return ''
	} 

	let newNumber = ($number - ($number mod $base)) / $base
	return ([(dec2base ($newNumber | into int) $base) ($chars | get ($number mod $base))] | str join)
}

#Custom base representation number to decimal
export def base2dec [
	s:string	#string
	b:int 		#base
] {
	let s = $s | str downcase

	if $b < 1 or $b > 16 {
		return-error "wrong base provided!"
	}
	if $b < 10 and ($s like $"[($b)-9]" or $s like '[a-f]') {
		return-error "malformed string according to its base"
	}
	if $s like '[g-z]' {
		return-error "malformed string!"
	}

	let length = ($s | str length) - 1
	mut decimal = 0
	let s = $s | split chars

	for i in 0..$length {
		let digit = (
			if ($s | get $i) like '[0-9]' {
				$s | get $i | into int
			} else if ($s | get $i) like '[a-f]' {
				($s | get $i | into int) + 10
			} else {
				return-error "wrong character found!"
			}
		)
		$decimal = $decimal + $digit * $b ** ($length - $i)
	}
	return $decimal
}

# Scale list to [a,b] interval
export def scale-minmax [a, b,input?] {
	let x = get-input $in $input

	let min = $x | math min
	let max = $x | math max

	$x 
	| each {|it| 
		(($it - $min) / ($max - $min)) * ($b - $a) + $a
	}
}

# Scale every column of a table (separately) to [a,b] interval
export def scale-minmax-table [a, b,input?] {
	let x = get-input $in $input
	let n_cols = $x | transpose | length
	let name_cols = $x | transpose | column2 0
	
	0..($n_cols - 1) | each {|i|
		($x | column2 $i) | scale-minmax $a $b | wrap ($name_cols | get $i)
	} 
	| reduce {|it, acc| 
		$acc | merge $it
	}
}

#exp function
export def "math exp" [ ] {
    each {|x| $E ** $x}
}

#random int
export def randi [
	n:int #select random int in 0..n
	--probabilities(-p):list<float> #use non uniform distribution
] { 
	#uniform distribution
	if ($probabilities | is-empty) {
		return (random int 0..$n)
	}

	#non uniform distribution
	if ($probabilities | length) < ($n + 1) {
		return-error $"there must be at least ($n + 1) probabilities!"
	}

	if ($probabilities | math sum) != 1 {
		return-error $"probabilities must add to 1!"
	}

	let random_value = random float 
	mut cumulative_probability = 0;

  	for $i in 0..($n - 1) {
  	  $cumulative_probability = $cumulative_probability + ($probabilities | get $i);
  	  if ($random_value <= $cumulative_probability) {
		return $i
  	  }
  	}

  	return $n
}

#random selection from a list or table
export def rand-select [
	x?	#list or table
	--index(-i) #return index of selection
] { 
	let xs = if ($x | is-empty) {$in} else {$x} 

	match ($xs | typeof) {
		"list" => {
				let len = $xs | length
				let idx = randi ($len - 1)
				let selection = $xs | get $idx

				if $index {
					return {selection: $selection, index: $idx}
				} else {
					return ($selection)
				}
			},
        "range" => {
                $xs 
                | range2list 
                | if $index {
                    rand-select -i
                  } else {
                    rand-select
                  }
            },
		"table" => {
				let col = $xs | columns | rand-select
				let selection = $xs | get $col | rand-select -i
				
				if $index {
					return {selection: $selection.selection, column: $col, index: $selection.index}
				} else {
					return ($selection.selection)
				}

			},
		_ => {return-error $"($xs | typeof) type not allowed!"}
	}
}

#binomial coefficient (C_k^n)
export def "math bin-coeff" [n:int, k:int] {
    if ($k > $n) {return 0}
    if ($k == 0 or $k == $n) {return 1}

    mut num = $n
    mut den = $k
    mut k_2 = $k

    while ( $k_2 > 1 ) {
        $k_2 = $k_2 - 1;
        $num = $num * ($n - $k_2)
        $den = $den * $k_2
    }

    $num / $den
}

#number of permutation of r elements in a set of n elements (P_r^n)
export def "math perm-coeff" [n:int, r:int] {
	($n - $r + 1)..($n) | range2list | math product
}

#fibonacci sequence
export def "math fibonacci" [n:int] {
	generate {|fib=[0, 1]| 
		{
			out: $fib.0, 
			next: [$fib.1, ($fib.0 + $fib.1)]
		} 
	} 
	| first $n
}

#skewness of a list of numbers
export def "math skew" [x?:number] {
	let list = if ($x | is-empty) {$in | into float} else {$x | into float}
	let n = ($list | length)
	let mean = ($list | math avg)
	let std = ($list | math stddev)

	if $std == 0 {
		return-error "skewness undefined due to std been 0"
	}

	let sum = (
		if ($list | typeof) == table {
			$list | rename data
		} else {
			$list | wrap data
		}
		| update data {|it| 
			($it.data - $mean) ** 3
	  	  } 
		| math sum 
		| get data
	)

	return ($sum / ($n * $std ** 3))
}

#kurtosis of a list of numbers
export def "math kurt" [x?:number] {
	let list = if ($x | is-empty) {$in | into float} else {$x | into float}
	let n = ($list | length)
	let mean = ($list | math avg)
	let std = ($list | math stddev)

	if $std == 0 {
		return-error "kurtosis undefined due to std been 0"
	}

	let sum = (
		if ($list | typeof) == table {
			$list | rename data
		} else {
			$list | wrap data
		}
		| update data {|it| 
			($it.data - $mean) ** 4 
	  	  } 
		| math sum 
		| get data
	)

	return ($sum / ($n * $std ** 4))
}

#multiplication of two lists element wise
export def "math prod-list" [
	list1:list 
	list2:list
] {
	let n1 = $list1 | length
	let n2 = $list2 | length	

	if ($n1 != $n2) {
		return-error "lists doesn't have the same size!"
	}

	mut prod = []
	for i in 0..($n1 - 1) {
		$prod = $prod ++ [(($list1 | get $i) * ($list2 | get $i))]
	}

	return $prod
}

#weighted mean
export def "math mean-w" [
	numbers:list 
	weigths:list
] {
	let n1 = $numbers | length
	let n2 = $weigths | length

	if ($n1 != $n2) {
		return-error "lists doesn't have the same size!"
	}

	if ($weigths | math sum) != 1 {
		return-error "weigths don't add to 1"
	}

	math prod-list $numbers $weigths | math sum
}

# Calculate all of the possible permutations (ways to arrange the elements) of a list.
#
# Examples:
#   # Calculate all possible ways to arrange [ 'foo', 'bar', 'baz' ]
#   [ 'foo', 'bar', 'baz' ] | permutations
#   # ->
#   # [
#   #   [ 'foo', 'bar', 'baz' ],
#   #   [ 'foo', 'baz', 'bar' ],
#   #   [ 'bar', 'foo', 'baz' ],
#   #   [ 'bar', 'baz', 'foo' ],
#   #   [ 'baz', 'bar', 'foo' ],
#   #   [ 'baz', 'foo', 'bar' ]
#   # ]
export def "math permutations" [
  --optional(-o) # Make all elements optional.
]: [ list -> list<list> ] {
  let input = $in

  # Base case: empty list has one permutation (the empty list itself)
  if ($input | is-empty) { 
    return [[ ]] # Return a list containing an empty list
  }

  # Recursive case: for each element in the input
  $input | reduce --fold [
    []
  ] {|element,acc|
    # 1. Calculate permutations of the remaining elements.
    let remaining = $input | where {|it| $it != $element }
    let sub_perms = $remaining | iter permutations --optional=($optional)

    # 2. For each of those permutations, insert the current element at every possible position.
    let with_element = ($sub_perms | each {|it|
      # Generate a range of indices from 0 to the length of the permutation
      let indices = (0..($it | length))

      # For each index, insert the current element at that position in the permutation
      $indices | each {|i| $it | insert $i $element } 
    } | flatten) # Flatten the nested list of permutations

    # 3. If optional is true, also add each permutation without the current element.
    if $optional {
      ($sub_perms | append $with_element) # Combine sub_perms and with_element
    } else {
      $with_element
    }
  }
}

#random incomplete table
export def "random table" [
    ncols:int 
    nrows:int 
    value?:int = 0 #fill
    --min(-m):int = 5 #minimum random value
    --max(-M):int = 100 #maximum random value
] {
    let sample_size = random int $min..$max 
    mut output = const-table $value $nrows -m $ncols
    let $r = $output

    for $i in 1..$sample_size {
        let value = random int $min..$max 
        let selection = ($r | rand-select -i) 
        let index = $selection.index 
        let column = $selection.column

        $output = $output | merge (
            $output 
            | get $column 
            | update $index $value 
            | wrap $column
        )
    }
    return ($output)
}

#get random sample from list
export def "math sample" [
	sample_size:int #size of the sample
	set? #set to take the sample from
	--replacement(-r) #sample with replacement
	--probabilities(-p):list #probability of each element in the set
] {
	let set = get-input $in $set
	let len = $set | length

	if ($probabilities | is-not-empty) {
		if ($probabilities | length) < $len {
			return-error $"must provide at least ($len) probabilities!"
		}
		if ($probabilities | math sum) != 1 {
			return-error "probabilities must add to 1!"
		}
	}

	# Sample with replacement
	if $replacement {
    	return (1..$sample_size | each {$set | get (randi ($len - 1) -p $probabilities)})
    }

	# Sample without replacement
    if $sample_size > $len {
        return-error "Cannot take a sample larger than the set."
    } 
    
    #uniform distribution
    if ($probabilities | is-empty) {
    	return ($set | shuffle | take $sample_size)
   	}

   	#non uniform distribution
   	mut temp = $set 
    mut sample = []
   	
   	for $i in 0..($sample_size - 1) {
   		let index = randi ($len - $i - 1) -p $probabilities
   		$sample = $sample ++ ($temp | get $index)
   		$temp = $temp | update $index ($temp | get ($len - $i - 1))
   	}

   	return $sample
} 

#cumulative sum of list
export def "math cumsum" [numbers?: list<number>] {
	let numbers = if ($numbers | is-empty) {$in} else {$numbers}
    mut acc = []

    for i in 0..<($numbers | length) {
        let sum = if $i == 0 {
            $numbers | get $i
        	} else {
            	($acc | get ($i - 1)) + ($numbers| get $i)
        	}
        $acc = $acc ++ $sum
    }

    return $acc
}

# Calculates the prime factors of a positive integer greater than 1.
# Returns a list of prime factors.
#
# Usage:
# > prime-factors 12
# [2 2 3]
# > prime-factors 30
# [2 3 5]
# > prime-factors 17
# [17]
# > prime-factors 1
# []
export def "math prime-factors" [
    number: int # The integer to factorize (must be > 1)
] {
    if $number <= 1 {
        # Prime factorization is typically defined for integers > 1.
        # Return an empty list for invalid input or edge cases like 1.
        return []
    }

    mut factors = []          # Initialize an empty mutable list to store factors
    mut current_number = $number # Create a mutable copy to modify

    # --- Step 1: Handle factor 2 ---
    # Divide by 2 as many times as possible
    while ($current_number mod 2 == 0) {
        $factors = ($factors | append 2) # Add 2 to the list of factors
        $current_number /= 2             # Update the number by integer division
    }

    # --- Step 2: Handle odd factors ---
    # Start checking odd factors from 3
    mut factor = 3
    # We only need to check factors up to the square root of the current number
    while ($factor * $factor <= $current_number) {
        # Divide by the current odd factor as many times as possible
        while ($current_number mod $factor == 0) {
            $factors = ($factors | append $factor) # Add the factor to the list
            $current_number /= $factor             # Update the number
        }
        # Move to the next odd number (no need to check even numbers after handling 2)
        $factor += 2
    }

    # --- Step 3: Handle the remaining number ---
    # If the remaining number is greater than 1 after the loop,
    # it must be a prime factor itself (larger than its square root).
    if $current_number > 1 {
        $factors = ($factors | append $current_number)
    }

    # Return the final list of prime factors
    return ($factors | into int)
}

# Solves a system of linear equations Ax = b using Gaussian elimination with partial pivoting.
#
# Usage:
#   solve-linear-system $A $b
#
# Parameters:
#   A: list<list<number>> - The coefficient matrix (must be square).
#   b: list<number> - The right-hand side vector (must have the same number of rows as A).
#
# Returns:
#   list<number> - The solution vector x, or an error if the matrix is singular or inputs are invalid.
#
# Example:
#   let A = [[1 2] [2 1]]
#   let b = [1 2]
#   solve-linear-system $A $b
#   # Expected output: [1.0 0.0]
export def "math solve-linear-system" [
    A: list<list<number>>, # Coefficient matrix A
    b: list<number>        # Right-hand side vector b
] {
    let n = $A | length # Number of equations/variables

    # --- Input Validation ---
    if $n == 0 {
        return-error "Input matrix A cannot be empty"
    }
    if ($b | length) != $n {
        return-error "Vector b must have the same number of elements as rows in matrix A"
    }
    for row in $A {
        if ($row | length) != $n {
            return-error "Matrix A must be square (same number of rows and columns)"
        }
    }

    # --- Create Augmented Matrix [A|b] ---
    # Convert all elements to float for calculations
    mut aug = (
        $A | enumerate | each {|it|
            let row_idx = $it.index
            let row_a = $it.item
            let val_b = $b | get $row_idx
            $row_a | append $val_b | each {|val| $val | into float}
        }
    )
    let num_cols = $n + 1
    let epsilon = 1e-15 # Small number for float comparison

    # --- Forward Elimination with Partial Pivoting ---
    for k in 0..<$n { # Iterate through pivot columns
        # Find pivot row
        mut max_row_index = $k
        mut max_val = $aug | get $k | get $k | math abs

        for i in ($k + 1)..<$n {
            let current_val = $aug | get $i | get $k | math abs
            if $current_val > $max_val {
                $max_val = $current_val
                $max_row_index = $i
            }
        }

        # Swap rows k and max_row_index if necessary
        if $max_row_index != $k {
            let temp_row = $aug | get $k
            $aug = $aug | update $k ($aug | get $max_row_index)
            $aug = $aug | update $max_row_index $temp_row
        }

        # Check for singularity (or near singularity)
        let pivot_val = $aug | get $k | get $k
        if ($pivot_val | math abs) < $epsilon {
            return-error $"Matrix is singular or nearly singular at column ($k). Cannot solve uniquely."
        }

        # Elimination: Make elements below the pivot zero
        for i in ($k + 1)..<$n {
            let factor = ($aug | get $i | get $k) / $pivot_val
            # Update row i: row_i = row_i - factor * row_k
            mut updated_row_i = $aug | get $i

            for j in $k..<$num_cols {
                let val_k = $aug | get $k | get $j
                let val_i = $aug | get $i | get $j
                let new_val = $val_i - $factor * $val_k
                $updated_row_i = $updated_row_i | update $j $new_val
            }
            # Set element below pivot explicitly to 0.0 to avoid potential float inaccuracies
            $updated_row_i = $updated_row_i | update $k 0.0
            $aug = $aug | update $i $updated_row_i # Update the matrix with the modified row
        }
    }

    # --- Back Substitution ---
    mut x = 0..<$n | each { 0.0 }

    # Iterate backwards from last row to first row
    for i in ($n - 1)..0 { 
        let pivot_val = $aug | get $i | get $i
         # Check for singularity during back-substitution
        if ($pivot_val | math abs) < $epsilon {
            # Use return-error for consistency
            return-error $"Zero pivot encountered during back-substitution at row ($i). Matrix is singular."
        }

        mut sum = $aug | get $i | get $n # Start with the b value of this row

        # Use ..<$n for iterating i+1 to n-1
        for j in ($i + 1)..<$n { # Subtract known x values multiplied by coefficients
            $sum = $sum - ($aug | get $i | get $j) * ($x | get $j)
        }

        $x = $x | update $i ($sum / $pivot_val) # Calculate and store x[i]
    }

    return $x
}
