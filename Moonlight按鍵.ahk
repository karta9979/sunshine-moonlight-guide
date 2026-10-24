#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ===== Moonlight 懸浮豬寶（全身版） =====
; 串流畫面在使用中時，畫面上會出現一個可拖動的小圓點：
;   - 按住拖動：移動豬寶位置（會記住相對於串流畫面的位置）
;   - 點一下：展開 / 收起功能選單
; 切到其他程式、最小化或結束串流時自動隱藏。

; ---------- 跟著 Moonlight 開關 ----------
; 執行這個檔案時，會順便打開 Moonlight；Moonlight 關掉後，豬寶也會自動結束。
; 所以平常（例如玩有反作弊的遊戲時）豬寶不會在背景執行。
MOONLIGHT_PATH := A_ProgramFiles "\Moonlight Game Streaming\Moonlight.exe"   ; Moonlight 安裝位置
if !ProcessExist("Moonlight.exe") {
    if FileExist(MOONLIGHT_PATH)
        Run(MOONLIGHT_PATH)
    else {
        MsgBox("找不到 Moonlight：`n" MOONLIGHT_PATH "`n`n請先手動開啟 Moonlight，或修改檔案裡的 MOONLIGHT_PATH。", "Moonlight 按鍵")
    }
}
if !ProcessWait("Moonlight.exe", 20)   ; 最多等 20 秒讓 Moonlight 開起來
    ExitApp()

; Moonlight 的串流畫面視窗（SDL 視窗）
STREAM_WIN := "ahk_class SDL_app ahk_exe Moonlight.exe"
DOT_W := 75     ; 懸浮豬寶寬度（像素，要跟 pig.png 一樣）
DOT_H := 96     ; 懸浮豬寶高度
TRANS_COLOR := "FF00FF" ; 透明用的底色（不用改）
ICON := A_ScriptDir "\pig.png"   ; 小圓點圖案，放在跟這個檔案同一個資料夾

; ---------- 小圓點 ----------
; +E0x08000000 = 點擊時不搶走焦點，Moonlight 保持在使用中
dotGui := Gui("+AlwaysOnTop +ToolWindow -Caption +E0x08000000")
dotGui.MarginX := 0
dotGui.MarginY := 0
if FileExist(ICON) {
    ; 背景設成洋紅色，再把洋紅色變透明 → 只看得到豬寶本身
    dotGui.BackColor := TRANS_COLOR
    dotGui.Add("Picture", "x0 y0 w" DOT_W " h" DOT_H " BackgroundTrans", ICON)
    dotGui.Show("w" DOT_W " h" DOT_H " Hide")
    WinSetTransColor(TRANS_COLOR, dotGui.Hwnd)
} else {                                   ; 找不到圖片時用灰色 ☰ 圓點
    DOT_W := 44, DOT_H := 44
    dotGui.BackColor := "2B2B2B"
    dotGui.SetFont("s16 cWhite", "Segoe UI Symbol")
    dotGui.Add("Text", "x0 y0 w44 h44 Center +0x200 BackgroundTrans", "☰")
    dotGui.Show("w44 h44 Hide")
    WinSetRegion("0-0 W44 H44 E", dotGui.Hwnd)
}

; ---------- 功能選單 ----------
menuGui := Gui("+AlwaysOnTop +ToolWindow -Caption +Border +E0x08000000")
menuGui.MarginX := 4
menuGui.MarginY := 4
menuGui.SetFont("s10", "Microsoft JhengHei")

AddBtn("切換螢幕 1",    "^!+{F1}")
AddBtn("切換螢幕 2",    "^!+{F2}")
AddBtn("複製（對方）",  "^c")       ; 在對方電腦複製，只能在對方電腦貼上
AddBtn("貼上我的文字",  "^!+v")     ; 把我這台複製的文字打到對方電腦
AddBtn("放開滑鼠",      "^!+z")
AddBtn("全螢幕/視窗",   "^!+x")
AddBtn("聲音 開/關",  (*) => MoonlightAudio("mute"))
AddBtn("音量 +",      (*) => MoonlightAudio(+10))
AddBtn("音量 −",      (*) => MoonlightAudio(-10))
AddBtn("結束串流",      "^!+q")
AddBtn("關閉豬寶",      (*) => ExitApp())   ; 這次不想用按鈕：豬寶結束，Moonlight 照常使用

menuGui.Show("AutoSize Hide")
menuGui.GetPos(, , &mw, &mh)

; ---------- 狀態 ----------
ox := ""          ; 小圓點相對於串流畫面左上角的位置
oy := ""
dotShown := false
menuOpen := false
dragging := false
lastX := ""
lastY := ""

OnMessage(0x201, OnDotDown)   ; 滑鼠左鍵按下
SetTimer(CheckStream, 200)
return

; =====================================================

AddBtn(label, action) {
    global menuGui
    btn := menuGui.Add("Button", "w130 h30", label)
    if (action is String)
        btn.OnEvent("Click", (*) => (HideMenu(), SendToMoonlight(action)))
    else
        btn.OnEvent("Click", (*) => action())   ; 聲音按鈕：選單保持開著，方便連按
}

Clamp(v, lo, hi) {
    return v < lo ? lo : (v > hi ? hi : v)
}

CheckStream() {
    global dotGui, dotShown, menuOpen, dragging, ox, oy, lastX, lastY
    if !ProcessExist("Moonlight.exe")   ; Moonlight 關掉了 → 豬寶跟著結束
        ExitApp()
    if dragging
        return
    if WinExist(STREAM_WIN) && WinActive(STREAM_WIN) && WinGetMinMax(STREAM_WIN) != -1 {
        WinGetClientPos(&cx, &cy, &cw, &ch, STREAM_WIN)
        if (ox = "") {                 ; 第一次出現：放在右側上方三分之一處
            ox := cw - DOT_W - 10
            oy := ch // 3
        }
        ox := Clamp(ox, 0, Max(cw - DOT_W, 0))
        oy := Clamp(oy, 0, Max(ch - DOT_H, 0))
        nx := cx + ox
        ny := cy + oy
        if (!dotShown || nx != lastX || ny != lastY) {
            dotGui.Show("x" nx " y" ny " NoActivate")
            lastX := nx
            lastY := ny
            if menuOpen
                PositionMenu()
        }
        dotShown := true
    } else {
        if dotShown {
            dotGui.Hide()
            dotShown := false
        }
        HideMenu()
    }
}

OnDotDown(wParam, lParam, msg, hwnd) {
    global dotGui, dragging, ox, oy
    ; 只處理點在小圓點上的情況
    if !(hwnd = dotGui.Hwnd || DllCall("GetParent", "ptr", hwnd, "ptr") = dotGui.Hwnd)
        return
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx0, &my0)
    WinGetPos(&wx0, &wy0, , , dotGui.Hwnd)
    dragging := true
    moved := false
    while GetKeyState("LButton", "P") {
        MouseGetPos(&mx, &my)
        if (!moved && (Abs(mx - mx0) > 5 || Abs(my - my0) > 5)) {
            moved := true
            HideMenu()
        }
        if moved
            WinMove(wx0 + mx - mx0, wy0 + my - my0, , , dotGui.Hwnd)
        Sleep(10)
    }
    dragging := false
    if moved {
        ; 記住新位置（相對於串流畫面）
        if WinExist(STREAM_WIN) {
            WinGetPos(&nx, &ny, , , dotGui.Hwnd)
            WinGetClientPos(&cx, &cy, &cw, &ch, STREAM_WIN)
            ox := Clamp(nx - cx, 0, Max(cw - DOT_W, 0))
            oy := Clamp(ny - cy, 0, Max(ch - DOT_H, 0))
        }
    } else {
        ToggleMenu()
    }
    return 0
}

ToggleMenu() {
    global menuOpen
    if menuOpen
        HideMenu()
    else
        ShowMenu()
}

ShowMenu() {
    global menuOpen
    menuOpen := true
    PositionMenu()
}

PositionMenu() {
    global menuGui, dotGui, mw, mh
    WinGetPos(&dx, &dy, , , dotGui.Hwnd)
    if WinExist(STREAM_WIN) {
        WinGetClientPos(&cx, &cy, &cw, &ch, STREAM_WIN)
    } else {
        cx := 0, cy := 0, cw := A_ScreenWidth, ch := A_ScreenHeight
    }
    ; 小圓點在右半邊 → 選單開在左側；在左半邊 → 開在右側
    if (dx + DOT_W // 2 > cx + cw // 2)
        mx := dx - mw - 6
    else
        mx := dx + DOT_W + 6
    my := Clamp(dy, cy, Max(cy + ch - mh, cy))
    menuGui.Show("x" mx " y" my " NoActivate")
}

HideMenu() {
    global menuGui, menuOpen
    if menuOpen {
        menuGui.Hide()
        menuOpen := false
    }
}

SendToMoonlight(keys) {
    if !WinExist(STREAM_WIN)
        return
    WinActivate(STREAM_WIN)
    if !WinWaitActive(STREAM_WIN, , 1)
        return
    Sleep(150)
    ; 用較慢、每個鍵按住一下的方式送出，Moonlight 比較不會漏收組合鍵
    SetKeyDelay(30, 40)
    SendEvent(keys)
}

; =====================================================
; 聲音控制：只調整「Moonlight 播出來的串流聲音」（= 你聽到的對方電腦聲音）
; 不會動到你自己電腦其他程式的音量，也不會改對方電腦的設定
; action = "mute" 切換靜音；數字 = 音量加減（百分比）
; =====================================================
MoonlightAudio(action) {
    vols := GetAppVolumes("Moonlight.exe")
    if (vols.Length = 0) {
        ShowTip("找不到 Moonlight 的聲音（串流中要有聲音播放過才抓得到）")
        return
    }
    if (action = "mute") {
        ComCall(6, vols[1], "int*", &m := 0)           ; GetMute
        for v in vols
            ComCall(5, v, "int", !m, "ptr", 0)          ; SetMute
        ShowTip(m ? "串流聲音：開" : "串流聲音：靜音")
    } else {
        ComCall(4, vols[1], "float*", &cur := 0)        ; GetMasterVolume
        nv := Max(0, Min(1, cur + action / 100))
        for v in vols {
            ComCall(3, v, "float", nv, "ptr", 0)        ; SetMasterVolume
            ComCall(5, v, "int", 0, "ptr", 0)           ; 調音量時順便解除靜音
        }
        ShowTip("串流音量：" Round(nv * 100) "%")
    }
}

GetAppVolumes(exeName) {
    vols := []
    pid := ProcessExist(exeName)
    if !pid
        return vols
    devEnum := ComObject("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
    ComCall(4, devEnum, "int", 0, "int", 1, "ptr*", &pDev := 0)          ; GetDefaultAudioEndpoint(喇叭)
    dev := ComValue(13, pDev)
    IID_Mgr2 := Buffer(16)
    DllCall("ole32\CLSIDFromString", "wstr", "{77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F}", "ptr", IID_Mgr2)
    ComCall(3, dev, "ptr", IID_Mgr2, "uint", 23, "ptr", 0, "ptr*", &pMgr := 0)   ; Activate
    mgr := ComValue(13, pMgr)
    ComCall(5, mgr, "ptr*", &pSE := 0)                                ; GetSessionEnumerator
    se := ComValue(13, pSE)
    ComCall(3, se, "int*", &cnt := 0)                                 ; GetCount
    loop cnt {
        ComCall(4, se, "int", A_Index - 1, "ptr*", &pCtl := 0)        ; GetSession
        ctl := ComValue(13, pCtl)
        ctl2 := ComObjQuery(ctl, "{bfb7ff88-7239-4fc9-8fa2-07c950be9c6d}")
        ComCall(14, ctl2, "uint*", &sPid := 0)                        ; GetProcessId
        if (sPid = pid)
            vols.Push(ComObjQuery(ctl, "{87CE5498-68D6-44E5-9215-6DA47EF883D8}"))   ; ISimpleAudioVolume
    }
    return vols
}

ShowTip(msg) {
    ToolTip(msg)
    SetTimer(() => ToolTip(), -1500)
}
