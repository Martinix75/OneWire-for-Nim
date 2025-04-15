# OneWire for Nim and Rp2040.
This library allows you to use Onewire devices, such as the "DS18B20" digital thermometer.
The installation of this library is not very simple, but not even impossible there are only more steps to make. Let's see how to do it.
Suppose we have a project named "Pippo", which uses this Onewire library (indicate only the files interested in changes or additions); and suppose that all the various dependencies are put in the directory "DEPS" (obviously it is arbitrary, only by way of example):
.
.
Pippo
  |
  |----- scr
  |        |----- Pippo.nim
  |        |
  |        |----- DEPS
  |                 |
  |                 |----- oneWire.nim
  |                 |----- oneWire_lib.pio
