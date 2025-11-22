WIZnet W5500 Ethernet
=====================

This is an example of using the WIZnet W5500 ethernet module with
an MSP430G2553. This is just simple UDP that sends the message
HELLO to a server.

Source code will require a change to set a proper IP address.
The code will simply send a UDP packet that has "HELLO" in it.
On the receiving side to test:

    nc -l -u 10000

Webpage coming soon.

https://www.mikekohn.net/

