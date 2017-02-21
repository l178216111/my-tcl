Imports System.Net.Sockets
Imports System.Net
Imports System.Text
Imports System.Threading
Public Class Main
    Private Declare Function SetForegroundWindow Lib "user32" (ByVal hwnd As IntPtr) As IntPtr
    Private Declare Function PostMessage Lib "user32" Alias "PostMessageA" (ByVal hwnd As Integer, ByVal wMsg As Integer, ByVal wParam As Integer, ByVal lParam As String) As Integer
    Private Declare Function SendMessage Lib "user32" Alias "SendMessageA" (ByVal hwnd As Integer, ByVal wMsg As Integer, ByVal wParam As Integer, ByVal lParam As String) As Integer
    Private Declare Function FindWindowEx Lib "user32" Alias "FindWindowExA" (ByVal hWnd1 As Integer, ByVal hWnd2 As Integer, ByVal lpsz1 As String, ByVal lpsz2 As String) As Integer
    Private Declare Function FindWindow Lib "user32" Alias "FindWindowA" (ByVal lpClassName As String, ByVal lpWindowName As String) As Integer
    Dim pass_word_show = password() & "e"
    Dim pass_word = "Teradyne"
    Dim s As Socket = Nothing
    'socket client thread
    Dim t As Thread
    'check exceed process is exist
    Dim flag_exceed As Boolean
    'socket return value
    Dim sendStr As String
    Public ReadOnly Property password() As String
        Get
            Return My.Settings.password
        End Get
    End Property
    Public ReadOnly Property socketport() As String
        Get
            Return My.Settings.port
        End Get
    End Property
    Private Sub Main_Load(sender As Object, e As EventArgs) Handles MyBase.Load
        Dim check_pro(2) As String
        Control.CheckForIllegalCrossThreadCalls = False
        t = New Thread(AddressOf WaitData)
        t.Start()
        check_pro = check_mode("pro")
        If check_pro(0) = "1" Then
            Mode.Text = "Eng"
            Engineer.Enabled = False
            Production.Enabled = True
        ElseIf check_pro(0) = "2" Then
            Mode.Text = "Pro"
            Engineer.Enabled = True
            Production.Enabled = False
        Else
            Mode.Text = "Pro"
            Engineer.Enabled = True
            Production.Enabled = False
            megbox("Pls Open Daemon")
        End If
    End Sub
    Private Sub Main_Closed(ByVal sender As Object, ByVal e As System.EventArgs) Handles MyBase.Closed
        Try
            s.Close()
            t.Abort()
        Catch
        End Try
    End Sub
    Public Sub WaitData()
        Dim local As String
        s = New Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp)
        Dim Ip() As System.Net.IPAddress = (System.Net.Dns.GetHostAddresses(System.Net.Dns.GetHostName))
        For Each Address In Ip '遍历本地的所有可用ip地址。
            If Address.AddressFamily = Net.Sockets.AddressFamily.InterNetwork Then
                local = Address.ToString
                textbox_ip.Text = local
                Exit For
            End If
        Next
        Try
            Dim localEndPoint As New IPEndPoint(IPAddress.Parse(local), socketport)
            s.Bind(localEndPoint)
        Catch ex As Exception
            MsgBox(ex.Message)
            Me.Close()
        End Try
        s.Listen(1)
        While (True)
            Dim bytes(4) As Byte
            Dim recive As Socket = s.Accept()
            recive.Receive(bytes)
            Dim mseeage = Encoding.UTF8.GetString(bytes)
            Select Case mseeage
                Case "cheng"
                    Dim result = change_eng_mode()
                    If result = "1" Then
                        sendStr = "Change mode success"
                    End If
                    Dim bs = Encoding.UTF8.GetBytes(sendStr)
                    recive.Send(bs, bs.Length, 0)
                Case "chpro"
                    Dim result = change_pro_mode()
                    If result = "1" Then
                        sendStr = "Change mode success"
                    End If
                    Dim bs = Encoding.UTF8.GetBytes(sendStr)
                    recive.Send(bs, bs.Length, 0)
                Case "check"
                    Dim sendStr = "pro"
                    Dim check_daemon(2) As String
                    check_daemon = check_mode("pro")
                    If check_daemon(0) = "1" Then
                        sendStr = "eng"
                    End If
                    Dim bs = Encoding.UTF8.GetBytes(sendStr)
                    recive.Send(bs, bs.Length, 0)
                Case Else
                    Dim bs = Encoding.UTF8.GetBytes("Error Commnad")
                    recive.Send(bs, bs.Length, 0)
            End Select
            recive.Close()
        End While
    End Sub

    Function check_mode(mode)
        'check daemon is running
        Dim hdWn_daemon = 0, hdwn_frame = 0, timeout = 0
        Do While (hdWn_daemon = 0 Or hdwn_frame = 0)
            hdWn_daemon = FindWindow("ThunderRT6FormDC", "IG-XL Tester Service Daemon")
            hdwn_frame = FindWindowEx(hdWn_daemon, 0, "ThunderRT6Frame", vbNullString)
            System.Threading.Thread.Sleep(50)
            timeout += 1
            If timeout > 5 Then
                Return New String() {"0", "No  Daemon Found"}
            End If
        Loop
        timeout = 0
        Select Case mode
            Case "daemon"
                Return New String() {"1", hdWn_daemon}
                'return mini windows hdwn
            Case "mini"
                Dim hdWn_window = 0
                Do While (hdWn_window = 0)
                    hdWn_window = FindWindow("ThunderRT6FormDC", "Open TstSvcD Window")
                    System.Threading.Thread.Sleep(50)
                    timeout += 1
                    If timeout > 5 Then
                        Return New String() {"0", "Pls change to Pro Mode and MiniSize Daemon"}
                    End If
                Loop
                Return New String() {"1", hdWn_window}
                'return Engineering button hdwn
            Case "eng"
                Dim hdwn_eng = 0
                Do While (hdwn_eng = 0)
                    hdwn_eng = FindWindowEx(hdwn_frame, 0, "ThunderRT6CommandButton", "Engineering")
                    System.Threading.Thread.Sleep(50)
                    timeout += 1
                    If timeout > 5 Then
                        Return New String() {"2", "Now is Engineering Mode"}
                    End If
                Loop
                Return New String() {"1", hdwn_eng}
                'return Produncetion button hdwn
            Case "pro"
                Dim hdwn_pro = 0
                Do While (hdwn_pro = 0)
                    hdwn_pro = FindWindowEx(hdwn_frame, 0, "ThunderRT6CommandButton", "Production")
                    System.Threading.Thread.Sleep(50)
                    timeout += 1
                    If timeout > 5 Then
                        Return New String() {"2", "Now  is Production Mode"}
                    End If
                Loop
                Return New String() {"1", hdwn_pro}
                'return Unload button hdwn
            Case "unload"
                Dim hdwn_frame1 = 0, hdwn_unload = 0, hdwn_load = 0, hdwn_frame2 = 0
                Do While (hdwn_frame1 = 0 Or hdwn_frame2 = 0)
                    hdwn_frame1 = FindWindowEx(hdWn_daemon, 0, "ThunderRT6Frame", vbNullString)
                    hdwn_frame2 = FindWindowEx(hdwn_frame1, 0, "ThunderRT6Frame", "Load Options")
                    System.Threading.Thread.Sleep(50)
                    timeout += 1
                    If timeout > 5 Then
                        Return New String() {"0", "Pls Check Daemon Version"}
                    End If
                Loop
                Do While (1)
                    hdwn_unload = FindWindowEx(hdwn_frame2, 0, "ThunderRT6CommandButton", "Unload")
                    hdwn_load = FindWindowEx(hdwn_frame2, 0, "ThunderRT6CommandButton", "Test Program Workbook")
                    If hdwn_unload <> 0 Then
                        Return New String() {"1", hdwn_unload}
                    End If
                    If hdwn_load <> 0 Then
                        Return New String() {"2", hdwn_load}
                    End If
                Loop

        End Select
        Return New String() {"0", "Error Command"}
    End Function
    Function unload()
        Dim unloadjob(2) As String
        unloadjob = check_mode("unload")
        If unloadjob(0) = "1" Then
            '    Dim result = kill_excel()
            '   If result = "1" Then
            SetForegroundWindow(unloadjob(1))
            PostMessage(unloadjob(1), 245, 0, 0)
            'Else
            '   Return result
            'End If
        ElseIf unloadjob(0) = "2" Then
        Else
        Return unloadjob(1)
        End If
        Dim check_unload(2) As String
        check_unload = check_mode("unload")
        Do While (1)
            check_unload = check_mode("unload")
            If check_unload(0) = "2" Then
                Return "1"
            End If
        Loop
    End Function
    Function daemon_recovery()
        Dim check_daemon(2) As String
        'get daemon hdwn
        check_daemon = check_mode("daemon")
        If check_daemon(0) = "1" Then
            PostMessage(check_daemon(1), 274, 61728, 0)
            Dim recovery_daemon(2) As String
            'check daemon if mini size
            recovery_daemon = check_mode("mini")
            If recovery_daemon(0) = "1" Then
                'recovery daemon
                Dim hdwn_edit = 0, hdwn_ok = 0, timeout = 0
                Do While (hdwn_edit = 0 Or hdwn_ok = 0)
                    hdwn_edit = FindWindowEx(recovery_daemon(1), 0, "ThunderRT6TextBox", vbNullString)
                    hdwn_ok = FindWindowEx(recovery_daemon(1), 0, "ThunderRT6CommandButton", "ok")
                    System.Threading.Thread.Sleep(50)
                    timeout += 1
                    If timeout > 5 Then
                        Return "Recovery Daemon Window Error "
                    End If
                Loop
                SendMessage(hdwn_edit, 12, 0, pass_word_show)
                SendMessage(hdwn_ok, 245, 0, 0)
                Return "1"
            Else
                'daemon is already recovery
                Return "1"
            End If
        Else
            Return check_daemon(1)
        End If
    End Function
    Function daemon_eng()
        Dim check_eng(2) As String
        check_eng = check_mode("eng")
        If check_eng(0) = 1 Then
            Dim show As String
            show = daemon_recovery()
            If show = "1" Then
                Dim Eng_hdwn As Integer = check_eng(1)
                SetForegroundWindow(Eng_hdwn)
                PostMessage(Eng_hdwn, 245, 0, 0)
                'input pass word
                Dim hdWn_engmode = 0, hdwn_edit = 0, hdwn_ok = 0, timeout = 0
                Do While (hdwn_edit = 0 Or hdwn_ok = 0 Or hdWn_engmode = 0)
                    hdWn_engmode = FindWindow("ThunderRT6FormDC", "Engineering Mode")
                    hdwn_edit = FindWindowEx(hdWn_engmode, 0, "ThunderRT6TextBox", vbNullString)
                    hdwn_ok = FindWindowEx(hdWn_engmode, 0, "ThunderRT6CommandButton", "OK")
                    System.Threading.Thread.Sleep(50)
                    timeout += 1
                    If timeout > 10 Then
                        Return "Entry Engineer Mode Error"
                    End If
                Loop
                SendMessage(hdWn_engmode, 274, 61728, 0)
                SendMessage(hdwn_edit, 12, 0, pass_word)
                'set Focus on "Engineer" button
                SetForegroundWindow(hdwn_ok)
                SendMessage(hdwn_ok, 245, 0, 0)
            Else
                megbox(show)
                Return "0"
            End If
        ElseIf check_eng(0) = 2 Then
            'already Eng mode
        Else : Return check_eng(1)
        End If
            Dim checkpro = check_mode("pro")
            If checkpro(0) = "1" Then
                Return "1"
        Else
            Dim daemon_hdwn = check_mode("daemon")
            PostMessage(daemon_hdwn(1), 274, 61472, 0)
            Return "Change Engineer Mode Error"
            End If
    End Function
    Function daemon_pro()
        'close config windows to avoid minsize daemon error
        Dim daemon_config_hdwn = FindWindow("ThunderRT6FormDC", "IG-XL Tester Service Daemon Configuration")
        If daemon_config_hdwn <> 0 Then
            PostMessage(daemon_config_hdwn, 16, 0, 0)
        End If
        'unload job
        Dim unloadjob = unload()
        If unloadjob = "1" Then
            Dim check_pro = check_mode("pro")
            If check_pro(0) = "1" Then
                Dim show As String
                show = daemon_recovery()
                If show = "1" Then
                    Dim Pro_hdwn As Integer = check_pro(1)
                    SetForegroundWindow(Pro_hdwn)
                    SendMessage(Pro_hdwn, 245, 0, 0)
                Else
                    megbox(show)
                    Return "0"
                End If
            ElseIf check_pro(0) = 2 Then
                'already Pro mode
            Else : Return check_pro(1)
            End If
            Dim checkeng = check_mode("eng")
            If checkeng(0) = "1" Then
                Dim daemon_hdwn = check_mode("daemon")
                PostMessage(daemon_hdwn(1), 274, 61472, 0)
                Return "1"
            Else
                Return "Change Pro Mode Error"
            End If
        Else
            Return unloadjob
        End If
    End Function
    Function change_eng_mode()
        Dim eng As String
        eng = daemon_eng()
        If eng = "1" Then
            Production.Enabled = True
            Engineer.Enabled = False
            Mode.Text = "Eng"
            Return "1"
        Else
            megbox(eng)
            Return "0"
        End If
    End Function
    Function change_pro_mode()

        Dim pro As String
        pro = daemon_pro()
        If pro = "1" Then
            Production.Enabled = False
            Engineer.Enabled = True
            Mode.Text = "Pro"
            Return "1"
        Else
            megbox(pro)
            Return "0"
        End If

    End Function
    Function check_exceed()
        If System.Diagnostics.Process.GetProcessesByName("exceed").Length > 0 Then
            Return 1
        Else
            Return 0
        End If
    End Function
    Function kill_excel()
        Dim i As Integer
        Dim Timeout = 0
        Dim proc As Process()
        If System.Diagnostics.Process.GetProcessesByName("excel").Length > 0 Then
            proc = Process.GetProcessesByName("excel")
            '得到名为excel进程个数，全部关闭
            For i = 0 To proc.Length - 1
                proc(i).Kill()
            Next
        End If
        Do While (1)
            If System.Diagnostics.Process.GetProcessesByName("excel").Length = 0 Then
                Return "1"
            End If
            System.Threading.Thread.Sleep(50)
            Timeout += 1
            If Timeout > 5 Then
                megbox("Can't Kill Program")
                Return "0"
            End If
        Loop
        Return "Can't Kill Program"
    End Function
    Sub megbox(mesage)
        flag_exceed = check_exceed()
        If flag_exceed = 0 Then
            MsgBox(mesage)
        Else
            sendStr = mesage
        End If
    End Sub


    Private Sub Production_Click(sender As Object, e As EventArgs) Handles Production.Click
        flag_exceed = check_exceed()
        If flag_exceed = True Then
            MsgBox("Pls close Exceed")
        Else
            change_pro_mode()
        End If

    End Sub

    Private Sub Engineer_Click(sender As Object, e As EventArgs) Handles Engineer.Click
        flag_exceed = check_exceed()
        If flag_exceed = True Then
            MsgBox("Pls close Exceed")
        Else
            change_eng_mode()
        End If
    End Sub
End Class
