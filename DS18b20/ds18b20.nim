import picostdlib
import picostdlib/pico/stdio
import picostdlib/hardware/[pio]
import std/[strutils]
import /DEPS/oneWire

let ds18b20Ver = "0.5.0" # vediamo che fare qui...

type
  Ds18b20 = object of OW
    ow: OW #strutta dati per usare onewire.
    dataDs: array[9, byte] #array contenete i dati mandati dal sensore.
    oneAddressDs: uint64 #memorizza un singolo indirizzo dei dispositivi.
    
# ----- Prototipe Procs -----
proc ds1820Init*(pio: PioInstance; gpio: uint):Ds18b20
proc search*(self: Ds18b20; maxdevs: int; command: int = 0xF0)
proc getAdress*(self: Ds18b20; numDev: uint=0): uint64
proc showAddress*(self: Ds18b20)
proc selectDevice*(self: var Ds18b20, addrDev: uint64)
proc getTempC*(self: var Ds18b20; numDev: uint=0; viewRaw: bool=false): float32
proc getAllTempC*(self: Ds18b20): seq[float]
proc setResolution*(self: var Ds18b20; numDev: uint=0; resolution: uint=10)
# ---------- Private ---------
proc initTxRead(self: Ds18b20)
proc initTxWrite(self: Ds18b20)
proc getAllDataBytes(self: Ds18b20; viewData: bool=false): seq[array[9,byte]]
proc writeByteConfig(self: Ds18b20; hexResolution: uint)
proc complementA2(self: Ds18b20; dataNeg: uint16): uint16
proc calculationCRC(self: Ds18b20; data: openArray[byte]): byte
# ----- End Prototipes ------
    
proc ds1820Init*(pio: PioInstance; gpio: uint): Ds18b20 =
  echo("Ds18b20 Init....")
  let ow_init = owInit(pio, gpio) #inizializza il bus onewire.
  result = Ds18b20(ow: ow_init)

proc search*(self: Ds18b20; maxdevs: int; command: int = 0xF0) =
  self.ow.owSearch(maxdevs, command.uint) #ceraca i dispositivi sul bus onewire (richiama funzioen apposita).

proc getAdress*(self: Ds18b20; numDev: uint=0): uint64 = #ricava un solo indirizzo
  try:
    result = self.ow.owGetAddress()[numDev] #ritorna l'indirizzo (funzione svolta da onewire).
  except IndexDefect:
    echo("No DS18b20 Present!!")
  
proc showAddress*(self: Ds18b20) =
  self.ow.owShowDevices()
  
proc selectDevice*(self: var Ds18b20, addrDev: uint64) = #seleziona il device da interrogare.
  try:
    echo("selezioinato --> ", toHex(addrDev))
    self.oneAddressDs = addrDev
  except IndexDefect:
    echo("No DS18b20 Present!!")

proc getTempC*(self: var Ds18b20; numDev: uint=0; viewRaw:bool=false): float32 = #torna la temperatura in gradi C° formattata corettamente (NON RAW).
  #echo("tempc")
  try: #correzione BUG1 (ver0.5.0).
    self.selectDevice(self.getAdress(numDev)) #richiama indirizzo desiderato e setta la letura su esso..
    let dataRaw = self.getAllDataBytes() #legge l'array con i dati grezzi della temperatura.
    #if self.calculationCRC(dataRaw[0]) == dataRaw[0][8]:#da troppe false errori
    let makeT: uint16 = dataRaw[numdev][0] or (uint16(dataRaw[numDev][1]) shl 8) #sposta di 8 bit il secondo byte e fa OR con il secondo.
    if (dataRaw[numDev][1] and 0xF8) == 0x00: #se la temperatura è positiva...
      #echo("IN Proc --> ", makeT shr 4, ".", temp[0] div 16) #da commentare.
      result = float32(makeT.float / 16.0)#shr 4 or temp[0] #ritorna il valore semi-grezzo.
    elif (dataRaw[numDev][1] and 0xF8) == 0xF8: #se la temperatura è negativa....
      let tempNeg = self.complementA2(makeT) #fa il complemento A2 del dato ricecuto sui due byte.
      result = float32(tempNeg.float / 16.0)*(-1) #ruitorna la temperatura (dop coamp A2) negativa (* -1).
  except IndexDefect: #correzione BUG1 (ver0.5.0).
    echo("getTempC Failed!")


proc getAllTempC*(self: Ds18b20): seq[float] = #test ritorno lista con i valori dei vari sensori(ver0.2.0).
  echo("All Temp C")
  let data = self.getAllDataBytes()
  echo("conversione arrai temp")
  for l in countUp(0, len(data)-1):
    let makeT = data[l][0] or (uint16(data[l][1]) shl 8)
    result.add(makeT.float / 16.0)
  echo("Temps -->>> ", result)

proc getResolution*(self: var Ds18b20; numDev: uint=0): uint = #dovrebbe ritornare la risolzione in bit (ver0.3.0).
  #echo("Ottieni i bit di risoluzione")
  try: #correzione BUG1 (ver0.5.0).
    self.selectDevice(self.getAdress(numDev)) #richiama indirizzo desiderato e setta la letura su esso.
    let data = self.getAllDataBytes()
    #echo("DAta Res --> ", data)
    case data[numDev][4]
    of 0x1F: result = 9
    of 0x3F: result = 10
    of 0x5F: result = 11
    of 0x7f: result = 12
    else: result = 0
  except IndexDefect: #correzione BUG1 (ver0.5.0).
    echo("getResolution Failed!")

proc setResolution*(self:var Ds18b20; numDev: uint=0; resolution: uint=10) = #scrive il numero di bit di risoluzione (ver0.3.0).
  echo("Imporsto il numero di bit..")
  self.selectDevice(self.getAdress(numDev))
  let hexConfig: uint = case resolution
                        of 9:  0x1F
                        of 10: 0x3F
                        of 11: 0x5F
                        of 12: 0x7F
                        else: 0x5F
  self.initTxWrite()
  self.writeByteConfig(hexConfig)
  
# ----- Private Procs ----------------------------------
proc initTxRead(self: Ds18b20) =
  #echo("Tx Read init")
  discard self.ow.owReset()
  self.ow.owWrite(0xCC)
  self.ow.owWrite(0x44)
  sleepMs(75)

proc initTxWrite(self: Ds18b20) =
  #echo("Tx Write init")
  discard self.ow.owReset()
  self.ow.owWrite(0x55) #forse 0xCC da vedere
  sleepMs(75)

proc getAllDataBytes(self: Ds18b20; viewData:bool=false): seq[array[9,byte]] = #seq[array[9, byte]] = #ottiene i byte dati grezzo. dei sensori (ver0.2.0).
  self.initTxRead()
  var temp_seq: array[9, byte]
  #var figa: seq[array[9, byte]]
  while self.ow.owRead() == 0:
    for j in countUp(0, self.ow.owGetNumDevices-1):
      discard self.ow.owReset()
      self.ow.owWrite(0x55)
      for n in countUp(0, 63, 8):
        self.ow.owWrite(uint(self.ow.owSelectDevice(j.uint8) shr n))
      self.ow.owWrite(0xBE)
      for l in countUp(0, 8):
        temp_seq[l] = self.ow.owRead()
      result.add(temp_seq)
  if viewData == true:
    echo("DATA ROW ---> ", result)
  sleepMs(75) #senza questa pausa potrebbe non leggere sempre bene i dati 75ms sembra buona per il caso peggiore a 12bit!
    
proc writeByteConfig(self: Ds18b20; hexResolution: uint) =
  for n in countUp(0, 63, 8):
      self.ow.owWrite(uint(self.oneAddressDs shr n)) #manda indirizzo device.
  self.ow.owWrite(0x4E)
  self.ow.owWrite(0x4B) #scrivi il valore di allarme Th (default 0x4B).
  self.ow.owWrite(0x46) #schivi il valore di allarme Tl (default 0x46)
  self.ow.owWrite(hexResolution) #ora scrivi il numero di bit di risoluzione
  discard self.ow.owReset()
  self.ow.owWrite(0x55)
  for n in countUp(0, 63, 8):
      self.ow.owWrite(uint(self.oneAddressDs shr n))
  self.ow.owWrite(0x48) #salva il byt trasmesso nella eprom del ds.

proc complementA2(self: Ds18b20; dataNeg: uint16): uint16 = #complemento a2 per le temperature negative (ver0.4.0)
  result = not(dataNeg)+1

proc calculationCRC(self: Ds18b20; data: openArray[byte]): byte = #calcolo crc se sore se ok torna zero (ver0.5.0).
  echo("Ricevo in CRC: ", data)
  echo("CRC ds18 --> ", toHex(data[8]))
  var 
    crc: byte = 0
    crc_raw: byte = 0
  for b in data:
    crc = crc xor b
    for _ in 0..7:
      if (crc and 0x1) != 0:
        crc = (crc shr 1) xor 0x8C
        crc_raw = crc
      else:
        crc = crc shr 1
  return crc_raw
                  
        
when isMainModule:
  import std/strformat
  stdioInitAll()
  sleepMs(1900)
  echo("Init ds18d20..")
  echo("Versione Onew: ", onewireVer)
  echo("Versione DS18B20: ", ds18b20Ver)
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
    #[echo("Temp2: ", ds.getTempC(numDev=1))
    echo("Temp2 resolution: ", ds.getResolution(numDev=1))
    echo("-----------------------------")]#
    sleepMs(4000)
