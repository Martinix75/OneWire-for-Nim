# Vaersiuone pre-build
import picostdlib
import picostdlib/hardware/[gpio, pio, clocks]
import picostdlib/pico/[stdio]
import std/[strutils] #dbug


{.push header: "onewire_lib.pio.h".}
var oneWireProgram {.importC: "onewire_program".}: PioProgram
proc oneWireProgramGetDefaultConfig(offset: uint): PioSmConfig  {.importC: "onewire_program_get_default_config".}
proc oneWireSmInit(pio: PioInstance; sm: uint; offset: uint; pinNum: uint; bitsPerWord: uint) {.importC: "onewire_sm_init".}
proc oneWireResetInstr(offset: uint):uint {.importC: "onewire_reset_instr".}
{.pop.}

let onewireVer* = "0.4.2"

type
  OW* = ref object # of RootObj #oggetto onewire ref (Ver0.4.0 eliminato RootBjg (Ver 0.4.2)).
    #onewireVer = "0.3.0" #versione libreria.
    pio: PioInstance
    sm: uint
    jmpReset: uint
    offset: int
    gpio: int
    romCodes: seq[uint64] #sequenza per contenere gli indirizzi(ver0.2.0).
    isPresent: bool = false #se false = no devices se true  = qualcosa di collegato ce (ver0.2.0).
    numberDevices: int #numeri dispositivi collegati sul bus onewire.


# ----- Prototipe Procs -----
proc owInit*(pio: PioInstance; gpio: uint): OW
#proc owVersion(self: OW): string
proc owWrite*(self: Ow; data: uint)
proc owRead*(self: OW): uint8
proc owReset*(self: OW): bool
proc owSearch*(self: OW; maxdevs: int; command: uint)
proc owIsPresent*(self: OW): bool
proc owShowDevices*(self: Ow)
proc owSelectDevice*(self: OW; numDev: uint8 = 0): uint64
proc owGetAddress*(self: OW): seq[uint64]
proc owGetNumDevices*(self:OW): int
# ----- End Prototipes ------
proc owInit*(pio: PioInstance; gpio: uint): OW = 
  echo("Init OneWire..")
  var
    offset_init: uint
    status: uint
  if canAddProgram(pio, oneWireProgram.addr):
    offset_init = addProgram(pio, oneWireProgram.addr)
  else:
    echo("Error add Program")
  let sm_init: int = claimUnusedSm(pio, false)
  if sm_init < 0:
    echo("Init Error")
  else:
    init(gpio.Gpio)
    gpioInit(pio, gpio.Gpio)
    result = OW(pio: pio, sm: uint(sm_init), jmpReset: oneWireResetInstr(offset_init), offset: int(offset_init), gpio: int(gpio))

#[proc owVersion(self: OW): string =
  result = self.onewireVer ]#

proc owWrite*(self: Ow; data: uint) = #cambio nome owSend --> owWrite ver0.2.0).
  smPutBlocking(self.pio, self.sm, uint32(data)) #trasmette il dato desiderato.
  discard smGetBlocking(self.pio, self.sm) #ascolta se riceve qualcosa.

proc owRead*(self: OW): uint8 =
  smPutBlocking(self.pio, self.sm, 0xFF) #trasmette questo dato per avere un risposta.
  result = uint8(smGetBlocking(self.pio, self.sm) shr 24) #prende la risposta.

proc owReset*(self: OW): bool = #necessaria per il corretto funzionamento del bus.
  smExecWaitBlocking(self.pio, self.sm, self.jmpReset)
  if ((smGetBlocking(self.pio, self.sm) and 1) == 0):
    result = true
  else:
    result = false

proc owSearch*(self: OW; maxdevs: int; command: uint) = #ricerca indirizzi dispositivi..
  var
    index_se: int = 0
    romcode_se: uint64 = 0
    branch_point_se: int
    next_branch_point_se: int = -1
    num_found_se: int = 0
    finish_se: bool = false
  self.romCodes.setLen(0)
  oneWireSmInit(self.pio, uint(self.sm), uint(self.offset), uint(self.gpio), uint(1))
  while finish_se == false and (maxdevs == 0 or num_found_se < maxdevs):
    finish_se = true
    branch_point_se = next_branch_point_se
    if self.owReset() == false:
      num_found_se = 0
      finish_se = true
      break
    var i = 0
    while i < 8:
      self.owWrite(command shr i)
      i = i+1
    index_se = 0
    while index_se < 64: #trtermina il rom-code (0..63 bit).
      let a: uint = self.owRead()
      let b: uint = self.owRead()
      if a == 0 and b == 0:
        if index_se == branch_point_se:
          self.owWrite(1)
          romcode_se = romcode_se or (uint64(1) shl index_se)
        else:
          if index_se > branch_point_se or (romcode_se and (uint64(1) shl index_se)) == 0:
            self.owWrite(0)
            finish_se = false
            romcode_se = romcode_se and not (uint64(1) shl index_se)
            next_branch_point_se = index_se
          else:
            self.owWrite(1)
      elif a != 0 and b != 0: #errore di dispositivo disconnesso!!
        num_found_se = -2
        finish_se = true
        break #termina il ciclo.
      else: 
        if a == 0:
          self.owWrite(0)
          romcode_se = romcode_se and not (uint64(1) shl index_se)
        else:
          self.owWrite(1)
          romcode_se = romcode_se or (uint64(1) shl index_se)
      index_se = index_se + 1
    #echo("-->: ",romcode_se, " -- ",toHex(romcode_se), " +++ ", romcode_se and 0x01)
    if (romcode_se and 0xFF) != 0: #risoluzione bug1 (ver0.2.0)
      #romcodes[num_found_se] = uint64(romcode_se) #memorizza il rom-code o i rom code.
      self.romCodes.add( uint64(romcode_se))
      num_found_se = num_found_se + 1
      self.isPresent = true
    else:
      #echo("No Devices Found! proc") #(ver0.2.0).
      self.isPresent = false
      num_found_se = num_found_se + 1
    #fine del ciclo.
  self.numberDevices = len(self.romCodes)
  oneWireSmInit(self.pio, uint(self.sm), uint(self.offset), uint(self.gpio), uint(8))
  #result = num_found_se

proc owIsPresent*(self: OW): bool = #ritorna true se ce almeno un dispositivo altrimenti false (ver0.2.0).
  result = self.isPresent

proc owSelectDevice*(self: OW; numDev: uint8 = 0): uint64 = #ritorna un solo indirizzo specifico (ver0.2.0).
  try: #prova che non si vada a selezionare valori fuori dalla lista.
    result = self.romCodes[numDev]
  except IndexDefect:
    echo("WARNING: max Val --> 0 to ", self.numberDevices-1, " but you have select --> ", numDev)
    result = 0x00
          
proc owShowDevices*(self: OW) = #utiliti per trovare dispositivi ed indirizzi sul bus onwewire (ver0.2.0).
  let elements = len(self.romCodes)
  if self.owIsPresent():
    echo("Found ", self.numberDevices, " devices")
    for x in countup(0, self.numberDevices-1):
      let g = toHex(self.romCodes[x])
      echo("Device Address: ", x, " --> ", g)
  else:
    echo("Device Not Found!")

proc owGetAddress*(self: OW): seq[uint64] = #ritorna l'arrai degli indirizzi (ver0.4.1).
  result = self.romCodes

proc owGetNumDevices*(self: OW): int = #ritorna il numero dispositivi sul bus (ver0.4.1).
  result = self.numberDevices


      
when isMainModule:
  stdioInitAll()
  sleepMs(1200)
  echo("Init....")
  let ow = owInit(pio = pio0, gpio = 15)
  echo("Onewire Version: ", onewireVer)
  let maxd: int = 10
  while true:
    ow.owSearch(maxd, 0xF0.uint)
    ow.owShowDevices()
    sleepMs(700)
    echo("Test selexione --> ", toHex(ow.owSelectDevice(1)))
    echo("Test numero Dispositivi --> ", ow.owGetNumDevices())
