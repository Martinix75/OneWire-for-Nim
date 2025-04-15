# OneWire for Nim and Rp2040.
This library allows you to use Onewire devices, such as the "DS18B20" digital thermometer.
The installation of this library is not very simple, but not even impossible there are only more steps to make. Let's see how to do it.
Suppose we have a project named "Pippo", which uses this Onewire library (indicate only the files interested in changes or additions); and suppose that all the various dependencies are put in the directory "DEPS" (obviously it is arbitrary, only by way of example):
```
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
  |----- build
  |          |
  |          |----- Pippo
  |
  |----- CMakeLists.txt
```
First copy the "Onewire.nim" and "Onewire_lib.pio" files in the "DEPS" folder. Then I should edit the "cmakelists.txt" file; the change to make is:
# pico_generate_pio_header(${OUTPUT_NAME} ${CMAKE_CURRENT_LIST_DIR}/src/DEPS/onewire_lib.pio)
Obviously if I have the "Onewire_lib.pio" libraty elsewhere the path above must be changed according to your real path. Well! Now you can try to compile (the example file that is automatically generated to the creation of the project is fine).
If everything went well in ".. Build/Pippo/" you should find the file (generated car) "Onewire_lib.pio.hio" which will be used by the "Onewire.nim" library to work correctly.
# For now this library is highly experimental and there may be changes in the future !!
