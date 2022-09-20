2022 seems to be the year of the 6522, not sure why
Whatever.

This is the source to a 6502 baord I made in which I
leverage the 6522 to do 9600 baud serial IO.

I was going to do a bunch of other things with it, but
it turns out the hardware they implemented the 6522 with
sucks (the low input current is crazy high, cause their input
have pullups (ARG)) (But wow, this chip!)

My terget is a monitor that allows for serial upload
but thats not in this code.

The system is: a 6502, attiny13 for clock generator and
reset control (this saves SO MUCH space its crazy), a 
GAL16V8 for address decoding (oh grrr crazy 6502 and random 
bus writes and clock synching and grrr) a 16k NVRAM chip and 
of course a 6522. 
Its set up to allow for two 6522's and an 8255 becasue I was
going to make an 8 channel servo loop controller out of it
becasue the pins on the 6522 can be individually set to 
input or output, which none of the other chips at the time
really did. But the input current! }:/

-- so 5 chips (7 if you add the extra 6522 and 8255) --

