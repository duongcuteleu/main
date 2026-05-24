#Requires AutoHotkey v2.0
#SingleInstance Force

; --- PHẦN CẤU HÌNH HỆ THỐNG ---
global URL_Github := "https://raw.githubusercontent.com/duongcuteleu/main/refs/heads/main/Key_list.json"
global IniFile := A_ScriptDir "\LicenseKey.ini"

global rows := 2
global cols := [0, 1]
global colW := 960
global rowH := 520
global StatusCheckboxes := []
global SelectAllChk := ""
global MyGui := ""
global IsSyncEnabled := false 
global BtnSync := ""         

; --- BIẾN TOÀN CỤC GIỚI HẠN TỌA ĐỘ THEO CẤU HÌNH (MẶC ĐỊNH BAN ĐẦU LÀ 2X2) ---
global limitW := 950
global limitH := 510

; --- CẤU HÌNH DÒNG CHỮ HIỂN THỊ TRÊN MÀN HÌNH (OSD) ---
global OSDGui := ""
global OSD_Text := "ĐANG ĐỒNG BỘ CLICK"  ; Nội dung chữ muốn hiển thị
global OSD_X := 780                     ; Tọa độ X: Đã tăng lên 580 để chữ lệch qua phải
global OSD_Y := -5                       ; Tọa độ Y: Đã giảm xuống 5 để chữ dịch lên trên
global OSD_Color := "00FF00"             ; Màu chữ (Mã màu HEX, 00FF00 là màu Xanh Lá)
global OSD_Size := "s16"                 ; Kích thước chữ (s16 = size 16)

; --- TỰ ĐỘNG KIỂM TRA KEY KHI KHỞI ĐỘNG ---
SavedKey := IniRead(IniFile, "License", "Key", "")

if (SavedKey != "") {
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", URL_Github, false)
        whr.Send()
        
        if (whr.Status == 200) {
            ServerTimeVN := GetServerTimeVN(whr)
            CheckStatus := CheckJsonLicenseAuto(SavedKey, whr.ResponseText, ServerTimeVN)
            
            if (CheckStatus == "VALID") {
                StartMainTool()
                return
            }
        }
    } catch {
        MsgBox("Không thể kiểm tra Key do lỗi kết nối Internet!", "Lỗi Hệ Thống", 16)
        ExitApp()
    }
}

; --- GIAO DIỆN NHẬP KEY ---
global KeyGui := Gui("+AlwaysOnTop", "Check Key")
KeyGui.OnEvent("Close", (*) => ExitApp())

KeyGui.Add("Text", "x20 y20", "Vui lòng nhập Key của bạn vào ô để kích hoạt:")
global EditKey := KeyGui.Add("Edit", "x20 y45 w360 r1 Uppercase", SavedKey)
global BtnCheck := KeyGui.Add("Button", "x150 y85 w100 h30 Default", "Kích Hoạt")
BtnCheck.OnEvent("Click", StartCheckKey)

KeyGui.Show("w400 h135")

; --- HÀM XỬ LÝ KHI BẤM NÚT KÍCH HOẠT ---
StartCheckKey(*) {
    UserKey := Trim(EditKey.Value)
    
    if (UserKey == "") {
        MsgBox("Vui lòng không để trống ô nhập Key!", "Thông báo", 48)
        return
    }
    
    BtnCheck.Enabled := false
    BtnCheck.Text := "Đang check..."
    
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", URL_Github, false)
        whr.Send()
        
        if (whr.Status == 200) {
            ServerTimeVN := GetServerTimeVN(whr)
            
            if CheckJsonLicense(UserKey, whr.ResponseText, ServerTimeVN) {
                IniWrite(UserKey, IniFile, "License", "Key")
                KeyGui.Destroy() 
                StartMainTool()  
                return           
            }
        } else {
            MsgBox("Không thể kết nối với server GitHub. Mã lỗi: " whr.Status, "Lỗi kết nối", 16)
        }
    } catch {
        MsgBox("Không thể kiểm tra Key do lỗi kết nối Internet!", "Lỗi Hệ Thống", 16)
        ExitApp()
    }
    
    BtnCheck.Enabled := true
    BtnCheck.Text := "Kích Hoạt"
}

; --- HÀM KIỂM TRA NGẦM KHI KHỞI ĐỘNG ---
CheckJsonLicenseAuto(InputKey, JsonString, ServerTime) {
    try {
        html := ComObject("htmlfile")
        html.write("<script>var data = " JsonString ";</script>")
        JsonObj := html.parentWindow.data
        
        Loop JsonObj.length {
            Item := JsonObj.%A_Index - 1%
            if (Item.key = InputKey) {
                ExpireString := Item.expire 
                RegExMatch(ExpireString, "(\d{2})/(\d{2})/(\d{4})\s(\d{2}):(\d{2})", &Match)
                if (!Match)
                    return "INVALID"
                
                AHK_ExpiryFormat := Match[3] Match[2] Match[1] Match[4] Match[5] "00"
                TimeDiff := DateDiff(AHK_ExpiryFormat, ServerTime, "Seconds") / 86400
                
                if (TimeDiff < 0) {
                    MsgBox("Key của bạn đã hết hạn vào lúc: " ExpireString "`nVui lòng gia hạn Key để tiếp tục sử dụng.", "Key Hết Hạn", 48)
                    ExitApp() 
                    return "EXPIRED"
                } else {
                    TrayTip("Hạn dùng đến: " ExpireString " (Còn " Round(TimeDiff, 1) " ngày)", "Tự ĐỘng Kích Hoạt", 64)
                    return "VALID" 
                }
            }
        }
    }
    return "INVALID"
}

; --- HÀM KIỂM TRA KEY CÓ BẢNG BÁO ---
CheckJsonLicense(InputKey, JsonString, ServerTime) {
    html := ComObject("htmlfile")
    html.write("<script>var data = " JsonString ";</script>")
    JsonObj := html.parentWindow.data
    KeyFound := false
    
    Loop JsonObj.length {
        Item := JsonObj.%A_Index - 1%
        if (Item.key = InputKey) {
            KeyFound := true
            ExpireString := Item.expire 
            
            RegExMatch(ExpireString, "(\d{2})/(\d{2})/(\d{4})\s(\d{2}):(\d{2})", &Match)
            if (!Match) {
                MsgBox("Định dạng ngày tháng trên GitHub bị sai cấu trúc!", "Lỗi dữ liệu", 16)
                ExitApp()
            }
            
            AHK_ExpiryFormat := Match[3] Match[2] Match[1] Match[4] Match[5] "00"
            TimeDiff := DateDiff(AHK_ExpiryFormat, ServerTime, "Seconds") / 86400
            
            if (TimeDiff < 0) {
                KeyGui.GetPos(&gX, &gY, &gW, &gH)
                
                ExpiredGui := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox", "Key Hết Hạn")
                ExpiredGui.SetFont("s10", "Segoe UI")
                ExpiredGui.Add("Text", "x20 y20 w320 Center", "Key của bạn đã hết hạn vào lúc: " ExpireString "`nVui lòng gia hạn Key để tiếp tục sử dụng!")
                btnOK := ExpiredGui.Add("Button", "x140 y70 w80 h25 Default", "OK")
                btnOK.OnEvent("Click", (*) => ExpiredGui.Destroy())
                
                errX := gX + (gW - 360) / 2
                errY := gY + gH - 10
                
                ExpiredGui.Show("x" errX " y" errY " w360 h110")
                ExitApp() 
                return false
            } else {
                TrayTip("Hạn dùng đến: " ExpireString " (Còn " Round(TimeDiff, 1) " ngày)", "Kích Hoạt Thành Công", 64)
                return true 
            }
        }
    }
    
    if (!KeyFound) {
        KeyGui.GetPos(&gX, &gY, &gW, &gH)
        
        ErrorGui := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox", "Sai Key!")
        ErrorGui.SetFont("s10", "Segoe UI")
        ErrorGui.Add("Text", "x20 y20 w300 Center", "Key bạn nhập không hợp lệ !`nVui lòng kiểm tra lại Key!")
        btnOK := ErrorGui.Add("Button", "x130 y60 w80 h25 Default", "OK")
        btnOK.OnEvent("Click", (*) => ErrorGui.Destroy())
        
        errX := gX + (gW - 340) / 2
        errY := gY + gH - 10
        
        ErrorGui.Show("x" errX " y" errY " w340 h100")
        return false 
    }
}

; --- HÀM LẤY GIỜ SERVER ---
GetServerTimeVN(whrObj) {
    try {
        serverDate := whrObj.GetResponseHeader("Date")
        html := ComObject("htmlfile")
        html.write("<script>function getZ(d){return ('0'+d).slice(-2);}; function parseDate(str){ var d = new Date(str); d.setHours(d.getHours()); return d.getFullYear() + getZ(d.getMonth()+1) + getZ(d.getDate()) + getZ(d.getHours()) + getZ(d.getMinutes()) + getZ(d.getSeconds()); }</script>")
        return html.parentWindow.parseDate(serverDate)
    } catch {
        return A_Now
    }
}

; --- PHẦN 2: GIAO DIỆN CHÍNH CỦA TOOL ---
StartMainTool() {
    CoordMode("Mouse", "Screen")
    SetDefaultMouseSpeed(0)
    SendMode "Input" 

    global rows, cols, colW, rowH, StatusCheckboxes, SelectAllChk, MyGui, BtnSync
    guiW := 430
    guiH := 280 

    MyGui := Gui("+AlwaysOnTop -MaximizeBox", "Đồng Bộ Click - Đa Cấu Hình")
    MyGui.OnEvent("Close", (*) => ExitApp())

    MyGui.Add("Text", "x20 y15", "Cấu hình:")
    Radio2x2 := MyGui.Add("Radio", "x90 y14 Group Checked", "2x2")
    Radio3x3 := MyGui.Add("Radio", "x150 y14", "3x3")
    Radio4x3 := MyGui.Add("Radio", "x210 y14", "4x3")
    Radio5x4 := MyGui.Add("Radio", "x270 y14", "5x4")

    Radio2x2.OnEvent("Click", ChangeLayout)
    Radio3x3.OnEvent("Click", ChangeLayout)
    Radio4x3.OnEvent("Click", ChangeLayout)
    Radio5x4.OnEvent("Click", ChangeLayout)

    SelectAllChk := MyGui.Add("Checkbox", "x20 y45 Checked", "Chọn tất cả")
    SelectAllChk.OnEvent("Click", ToggleAll)
    MyGui.Add("Text", "x120 y46 cGray", "(Tích/Bỏ tích để chọn nhanh)")

    BtnSync := MyGui.Add("Button", "x20 y230 w390 h35", "ĐỒNG BỘ: ĐANG TẮT")
    BtnSync.SetFont("bold cRed s10")
    BtnSync.OnEvent("Click", ToggleSyncState)

    UpdateGrid(2, [0, 1], 960, 520)

    spawnX := A_ScreenWidth - guiW - 10
    spawnY := A_ScreenHeight - guiH - 75
    MyGui.Show("x" spawnX " y" spawnY " w" guiW " h" guiH)

    ; Khởi tạo sẵn cửa sổ hiển thị chữ OSD ẩn ngầm
    InitOSD()

    SetTimer(LoopCheckKeyServer, 300000)
}

; --- HÀM KHỞI TẠO CỬ SỔ HIỂN THỊ CHỮ (OSD) ---
InitOSD() {
    global OSDGui, OSD_Text, OSD_Color, OSD_Size, OSD_X, OSD_Y
    ; Tạo Gui không viền, không thanh tiêu đề, luôn trên cùng, bỏ qua tương tác chuột (-Caption +AlwaysOnTop +E0x20)
    OSDGui := Gui("-Caption +AlwaysOnTop +Owner +E0x20")
    OSDGui.BackColor := "EEAA99" ; Đặt màu nền tạm thời để làm trong suốt
    WinSetTransColor("EEAA99", OSDGui) ; Biến màu nền thành trong suốt hoàn toàn (chỉ giữ lại chữ)
    
    OSDGui.SetFont(OSD_Size " bold", "Segoe UI")
    OSDGui.Add("Text", "c" OSD_Color, OSD_Text)
}

; --- HÀM BẬT/TẮT TRẠNG THÁI ĐỒNG BỘ TRÊN GUI ---
ToggleSyncState(*) {
    global IsSyncEnabled, BtnSync, MyGui, OSDGui, OSD_X, OSD_Y
    IsSyncEnabled := !IsSyncEnabled 
    
    if (IsSyncEnabled) {
        BtnSync.Text := "ĐỒNG BỘ: ĐANG BẬT"
        BtnSync.SetFont("bold cGreen s10") 
        
        ; Hiển thị dòng chữ tại tọa độ cố định
        if (OSDGui) {
            OSDGui.Show("X" OSD_X " Y" OSD_Y " NoActivate")
        }
        
        ; ẨN MENU XUỐNG KHI ĐANG BẬT ĐỒNG BỘ
        if (MyGui) {
            MyGui.Minimize()
        }
    } else {
        BtnSync.Text := "ĐỒNG BỘ: ĐANG TẮT"
        BtnSync.SetFont("bold cRed s10")   
        
        ; Ẩn dòng chữ đi khi tắt đồng bộ
        if (OSDGui) {
            OSDGui.Hide()
        }
    }
}

; --- HÀM HẸN GIỜ CHECK KEY ĐỊNH KỲ ---
LoopCheckKeyServer() {
    global MyGui, IniFile, URL_Github, OSDGui
    CurrentKey := IniRead(IniFile, "License", "Key", "")
    if (CurrentKey == "") {
        SetTimer(, 0)
        MsgBox("Không tìm thấy dữ liệu Key trong hệ thống!`nỨng dụng sẽ tự động đóng.", "Lỗi Bản Quyền", 16)
        ExitApp()
    }

    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", URL_Github, false)
        whr.Send()
        
        if (whr.Status == 200) {
            ServerTimeVN := GetServerTimeVN(whr)
            
            html := ComObject("htmlfile")
            html.write("<script>var data = " whr.ResponseText ";</script>")
            JsonObj := html.parentWindow.data
            
            KeyFound := false
            Loop JsonObj.length {
                Item := JsonObj.%A_Index - 1%
                if (Item.key = CurrentKey) {
                    KeyFound := true
                    ExpireString := Item.expire 
                    
                    RegExMatch(ExpireString, "(\d{2})/(\d{2})/(\d{4})\s(\d{2}):(\d{2})", &Match)
                    if (Match) {
                        AHK_ExpiryFormat := Match[3] Match[2] Match[1] Match[4] Match[5] "00"
                        TimeDiff := DateDiff(AHK_ExpiryFormat, ServerTimeVN, "Seconds") / 86400
                        
                        if (TimeDiff < 0) {
                            SetTimer(, 0)
                            if (MyGui)
                                MyGui.Destroy()
                            if (OSDGui)
                                OSDGui.Destroy()
                            
                            MsgBox("Key của bạn đã hết hạn vào lúc: " ExpireString "`nVui lòng gia hạn Key để tiếp tục sử dụng.", "Key Đã Hết Hạn", 48)
                            ExitApp()
                        }
                    }
                    break
                }
            }
            
            if (!KeyFound) {
                SetTimer(, 0)
                if (MyGui)
                    MyGui.Destroy()
                if (OSDGui)
                    OSDGui.Destroy()
                MsgBox("Key của bạn không còn hợp lệ hoặc đã bị xóa khỏi hệ thống!", "Key Không Hợp Lệ", 16)
                ExitApp()
            }
        } else {
            SetTimer(, 0)
            MsgBox("Không thể xác thực bản quyền do lỗi máy chủ Internet!", "Lỗi Bản Quyền", 16)
            ExitApp()
        }
    } catch {
        SetTimer(, 0)
        MsgBox("Không thể kiểm tra Key định kỳ do lỗi kết nối Internet", "Lỗi Hệ Thống", 16)
        ExitApp()
    }
}

; --- PHẦN 3: CÁC HÀM LOGIC XỬ LÝ LƯỚI & CLICK ---
ChangeLayout(CtrlObj, *) {
    global limitW, limitH
    switch CtrlObj.Text {
        case "2x2": 
            limitW := 950, limitH := 510
            UpdateGrid(2, [0, 1], 960, 520)
        case "3x3": 
            limitW := 635, limitH := 340
            UpdateGrid(3, [0, 1, 2], 640, 346)
        case "4x3": 
            limitW := 469, limitH := 332
            UpdateGrid(3, [0, 1, 2, 3], 480, 340)
        case "5x4": 
            limitW := 375, limitH := 253
            UpdateGrid(4, [0, 1, 2, 3, 4], 384, 260)
    }
}

UpdateGrid(newRows, newCols, w, h) {
    global rows, cols, colW, rowH, StatusCheckboxes, MyGui, SelectAllChk
    rows := newRows
    cols := newCols
    colW := w
    rowH := h
    
    for chk in StatusCheckboxes {
        try DllCall("DestroyWindow", "Ptr", chk.Hwnd)
    }
    StatusCheckboxes := [] 
    SelectAllChk.Value := 1

    displayIndex := 1 

    Loop rows {
        currRow := A_Index - 1
        for currCol in cols {
            if (currRow == 0 && currCol == 0) {
                StatusCheckboxes.Push({Value: 0, Hwnd: 0})
                displayIndex++ 
                continue
            }

            guiX := 20 + (currCol * 80)
            guiY := 80 + (currRow * 35)
            
            chk := MyGui.Add("Checkbox", "x" guiX " y" guiY " Checked", displayIndex)
            
            chk.OnEvent("Click", CheckChildStatus)
            StatusCheckboxes.Push(chk)
            displayIndex++
        }
    }
    MyGui.Show("NoActivate") 
}

CheckChildStatus(*) {
    global StatusCheckboxes, SelectAllChk
    allChecked := 1
    
    for chk in StatusCheckboxes {
        if (chk.Hwnd == 0)
            continue
            
        if (chk.Value == 0) {
            allChecked := 0
            break
        }
    }
    SelectAllChk.Value := allChecked
}

ToggleAll(*) {
    global SelectAllChk, StatusCheckboxes
    currentValue := SelectAllChk.Value
    for chk in StatusCheckboxes {
        if (chk.Hwnd == 0) {
            chk.Value := 0
            continue
        }
        chk.Value := currentValue
    }
}

; --- ĐIỀU KIỆN KÍCH HOẠT HOTKEY ---
#HotIf (MyGui && IsSyncEnabled == true)

; Đã xóa bỏ dấu ~ để chống double click hoàn toàn
$LButton Up::
{
    global rows, cols, colW, rowH, StatusCheckboxes, MyGui, limitW, limitH
    
    if (StatusCheckboxes.Length == 0)
        return

    ; Lấy tọa độ chuột thật ngay khi vừa nhấc chuột
    MouseGetPos(&x, &y, &MouseWinID)
    
    ; Nếu click vào chính giao diện Tool thì bỏ qua không đồng bộ
    if (MouseWinID == MyGui.Hwnd)
    {
        hitTest := SendMessage(0x0084, 0, (y << 16) | (x & 0xFFFF), , MyGui.Hwnd)
        if (hitTest == 8 || hitTest == 20)
            return
        return
    }

    ; Tạm thời tắt Hotkey chặn để chống lặp vô hạn
    HotKey("$LButton Up", "Off")

    ; Tự gửi duy nhất 1 cú click thật tại vị trí chuột hiện tại của bạn
    Click(x " " y)
    Sleep(70) ; Chờ 70ms cho game ghi nhận click chính xác

    ; --- ĐIỀU KIỆN CLICK ĐỒNG BỘ THEO TỪNG CẤU HÌNH ---
    if (x >= 0 && x <= limitW && y >= 0 && y <= limitH)
    {
        checkboxIndex := 1 

        Loop rows
        {
            row := A_Index - 1
            for col in cols
            {
                ; Nếu ô này được tích chọn đồng bộ
                if (StatusCheckboxes[checkboxIndex].Value == 1) 
                {
                    clickX := x + (colW * col)
                    clickY := y + (rowH * row)
                    
                    ; Click thẳng vào tọa độ mục tiêu đồng bộ
                    Click(clickX " " clickY)
                    Sleep(100) 
                }
                checkboxIndex++ 
            }
        }
        
        ; Đưa trỏ chuột về lại đúng vị trí ban đầu của bạn
        MouseMove(x, y)
    }
    
    ; Bật lại Hotkey cho lần nhấp chuột tiếp theo
    HotKey("$LButton Up", "On")
}

MButton:: {
    global IsSyncEnabled, BtnSync, MyGui, OSDGui
    
    if (MyGui) {
        MyGui.Restore() 
    }

    if (IsSyncEnabled == true) {
        IsSyncEnabled := false
        BtnSync.Text := "ĐỒNG BỘ: ĐANG TẮT"
        BtnSync.SetFont("bold cRed s10") 
        
        ; Ẩn OSD khi tắt bằng phím chuột giữa (MButton)
        if (OSDGui) {
            OSDGui.Hide()
        }
    }
}
#HotIf
