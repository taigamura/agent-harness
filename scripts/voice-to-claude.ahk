#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent()
SetWorkingDir A_ScriptDir

ProjectRoot   := A_ScriptDir "\.."
FfmpegExe     := ProjectRoot "\bin\Release\ffmpeg.exe"
PwshScript    := ProjectRoot "\scripts\transcribe.ps1"
TmpDir        := ProjectRoot "\tmp"
WavCurrent    := TmpDir "\current.wav"
WavFinal      := TmpDir "\final.wav"
DshowDevice   := "@device_cm_{33D9A762-90C8-11D0-BD43-00A0C911CE86}\wave_{39FF19C7-A041-4927-A3DD-F683029BF267}"
MaxSeconds    := 120

if !DirExist(TmpDir)
    DirCreate(TmpDir)

global RecState := "idle"
global FfmpegPid := 0
global RecStartTick := 0

TraySetIcon("imageres.dll", 109)
A_IconTip := "Voice to Claude — idle"

SetStatus(state) {
    global RecState
    RecState := state
    label := Map("idle", "idle", "recording", "● RECORDING", "transcribing", "… transcribing")
    A_IconTip := "Voice to Claude — " label[state]
}

StartRecording() {
    global FfmpegPid, RecStartTick, FfmpegExe, WavCurrent, DshowDevice, MaxSeconds

    if FileExist(WavCurrent)
        FileDelete(WavCurrent)

    args := Format('"{1}" -hide_banner -loglevel error -y -f dshow -i "audio={2}" -ac 1 -ar 16000 -acodec pcm_s16le -t {3} "{4}"',
        FfmpegExe, DshowDevice, MaxSeconds, WavCurrent)

    Run(args, , "Hide", &spawnedPid)
    FfmpegPid := spawnedPid
    RecStartTick := A_TickCount
    SetStatus("recording")
}

StopRecording() {
    global FfmpegPid, RecStartTick, WavCurrent, WavFinal, FfmpegExe, PwshScript, TmpDir

    durationMs := A_TickCount - RecStartTick

    if FfmpegPid {
        RunWait('taskkill /PID ' FfmpegPid, , "Hide")
        deadline := A_TickCount + 1500
        while ProcessExist(FfmpegPid) && A_TickCount < deadline
            Sleep(50)
        if ProcessExist(FfmpegPid)
            RunWait('taskkill /PID ' FfmpegPid ' /T /F', , "Hide")
        FfmpegPid := 0
    }

    Sleep(100)

    if durationMs < 400 {
        SetStatus("idle")
        return
    }

    if !FileExist(WavCurrent) {
        SetStatus("idle")
        TrayTip("Voice to Claude", "No audio captured", 1)
        return
    }

    SetStatus("transcribing")

    if FileExist(WavFinal)
        FileDelete(WavFinal)
    RunWait(Format('"{1}" -hide_banner -loglevel error -y -i "{2}" -c copy "{3}"', FfmpegExe, WavCurrent, WavFinal), , "Hide")

    transcriptFile := TmpDir "\last.txt"
    logFile        := TmpDir "\last-run.log"
    if FileExist(transcriptFile)
        FileDelete(transcriptFile)
    if FileExist(logFile)
        FileDelete(logFile)

    wavToUse := FileExist(WavFinal) ? WavFinal : WavCurrent
    cmd := Format('cmd.exe /c powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{1}" -WavPath "{2}" > "{3}" 2> "{4}"',
        PwshScript, wavToUse, transcriptFile, logFile)
    rc := RunWait(cmd, , "Hide")

    text := ""
    if FileExist(transcriptFile)
        text := Trim(FileRead(transcriptFile, "UTF-8"), " `t`r`n")

    if text = "" {
        errSnippet := FileExist(logFile) ? SubStr(FileRead(logFile, "UTF-8"), 1, 200) : "(no log)"
        SetStatus("idle")
        TrayTip("Voice to Claude", "Empty transcription (rc=" rc "): " errSnippet, 1)
        return
    }

    PasteText(text)
    SetStatus("idle")
}

PasteText(text) {
    saved := A_Clipboard
    A_Clipboard := ""
    A_Clipboard := text
    if !ClipWait(1) {
        TrayTip("Voice to Claude", "Clipboard set failed", 1)
        return
    }
    Send("^v")
    Sleep(120)
    A_Clipboard := saved
}

*RAlt:: {
    global RecState
    if RecState = "idle"
        StartRecording()
}

*RAlt up:: {
    global RecState
    if RecState = "recording"
        StopRecording()
}

^!+R::Reload
^!+Q::ExitApp
