#!/usr/bin/env nu

let pi = 3.1415926535897932 	#pi
let e = 2.7182818284590452  	#exp(1)
let gamma = 0.5772156649015328	#Euler–Mascheroni constant
let phi = 1.6180339887498948	#Golden ratio

# (fetch https://api.chucknorris.io/jokes/random).value
fetch -H ["Accept" "text/plain"] https://icanhazdadjoke.com