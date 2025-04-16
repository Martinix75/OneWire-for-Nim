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
