# DS18b20 Library for Digital Thermometer.
# This bookcase needs the byalpendence of "Onewire. Nim".
The use of the library should be easy. Once you care about your program, you just need to initialize the sensor with:
```
ds1820Init(pio0, 15)
```
Where: pioX in the Pio instance (pio0 or pio1) and the second parameter is the PIN (Gpio) where the sensor will be connected (15 Gpio in this case).
Use the "search()" function to look for the addresses of the devices on the bus.
You can now use the "Setresolution ()" procedure to set the number of temperature reading bits.
```
setResolution(numDev=0, resolution=12)
```
In this example, the reading of the first device is set at 12 bits. Now to read the temperature you just need to do:
```
getTempC(numDev=0)
```
Below is a small example:
```nim
import std/strformat
  stdioInitAll()
  sleepMs(1900)
  echo("Init ds18d20..")
  echo("Version Onew: ", onewireVer)
  echo("Version DS18B20: ", ds18b20Ver)
  var ds = ds1820Init(pio0, 15)
  #-------------------------------------
  ds.search(5)
  ds.showaddress()
  ds.setResolution(numDev=0, resolution=12)
  ds.setResolution(numDev=1, resolution=12)
  while true:
    echo("-----------------------------")
    echo("Temp1: ", ds.getTempC(numDev=0))
    echo("Temp1 resolution: ", ds.getResolution(numDev=0))
    echo("++++++++++++++++++++++++++++++")
    sleepMs(4000)
```
For now, reading is only in degrees centigrade, for other systems the conversion must be done manually (but in the next versions it is not excluded that I put this option).

# Attention! This library is still being developed!

