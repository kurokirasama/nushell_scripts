#!/usr/bin/env nu

let pi = math pi 				#pi
let e = math e  				#exp(1)
let gamma = 0.5772156649015328	#Euler–Mascheroni constant
let phi = 1.6180339887498948	#Golden ratio

# (fetch https://api.chucknorris.io/jokes/random).value
fetch -H ["Accept" "text/plain"] https://icanhazdadjoke.com