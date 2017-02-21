<Global.Microsoft.VisualBasic.CompilerServices.DesignerGenerated()> _
Partial Class Main
    Inherits System.Windows.Forms.Form

    'Form 重写 Dispose，以清理组件列表。
    <System.Diagnostics.DebuggerNonUserCode()> _
    Protected Overrides Sub Dispose(ByVal disposing As Boolean)
        Try
            If disposing AndAlso components IsNot Nothing Then
                components.Dispose()
            End If
        Finally
            MyBase.Dispose(disposing)
        End Try
    End Sub

    'Windows 窗体设计器所必需的
    Private components As System.ComponentModel.IContainer

    '注意:  以下过程是 Windows 窗体设计器所必需的
    '可以使用 Windows 窗体设计器修改它。  
    '不要使用代码编辑器修改它。
    <System.Diagnostics.DebuggerStepThrough()> _
    Private Sub InitializeComponent()
        Me.Engineer = New System.Windows.Forms.Button()
        Me.Production = New System.Windows.Forms.Button()
        Me.Mode = New System.Windows.Forms.TextBox()
        Me.Label2 = New System.Windows.Forms.Label()
        Me.Label1 = New System.Windows.Forms.Label()
        Me.textbox_ip = New System.Windows.Forms.TextBox()
        Me.SuspendLayout()
        '
        'Engineer
        '
        Me.Engineer.Location = New System.Drawing.Point(12, 12)
        Me.Engineer.Name = "Engineer"
        Me.Engineer.Size = New System.Drawing.Size(75, 23)
        Me.Engineer.TabIndex = 1
        Me.Engineer.Text = "Engineer"
        Me.Engineer.UseVisualStyleBackColor = True
        '
        'Production
        '
        Me.Production.Location = New System.Drawing.Point(12, 41)
        Me.Production.Name = "Production"
        Me.Production.Size = New System.Drawing.Size(75, 23)
        Me.Production.TabIndex = 2
        Me.Production.Text = "Production"
        Me.Production.UseVisualStyleBackColor = True
        '
        'Mode
        '
        Me.Mode.Location = New System.Drawing.Point(178, 42)
        Me.Mode.Name = "Mode"
        Me.Mode.ReadOnly = True
        Me.Mode.Size = New System.Drawing.Size(43, 21)
        Me.Mode.TabIndex = 9
        '
        'Label2
        '
        Me.Label2.AutoSize = True
        Me.Label2.Location = New System.Drawing.Point(94, 46)
        Me.Label2.Name = "Label2"
        Me.Label2.Size = New System.Drawing.Size(83, 12)
        Me.Label2.TabIndex = 8
        Me.Label2.Text = "Current Mode:"
        '
        'Label1
        '
        Me.Label1.AutoSize = True
        Me.Label1.Location = New System.Drawing.Point(94, 17)
        Me.Label1.Name = "Label1"
        Me.Label1.Size = New System.Drawing.Size(23, 12)
        Me.Label1.TabIndex = 7
        Me.Label1.Text = "IP:"
        '
        'textbox_ip
        '
        Me.textbox_ip.Location = New System.Drawing.Point(121, 14)
        Me.textbox_ip.Name = "textbox_ip"
        Me.textbox_ip.ReadOnly = True
        Me.textbox_ip.Size = New System.Drawing.Size(100, 21)
        Me.textbox_ip.TabIndex = 6
        '
        'Main
        '
        Me.AutoScaleDimensions = New System.Drawing.SizeF(6.0!, 12.0!)
        Me.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font
        Me.ClientSize = New System.Drawing.Size(233, 84)
        Me.ControlBox = False
        Me.Controls.Add(Me.Mode)
        Me.Controls.Add(Me.Label2)
        Me.Controls.Add(Me.Label1)
        Me.Controls.Add(Me.textbox_ip)
        Me.Controls.Add(Me.Production)
        Me.Controls.Add(Me.Engineer)
        Me.MaximizeBox = False
        Me.MinimizeBox = False
        Me.Name = "Main"
        Me.Text = "Daemon Lock"
        Me.ResumeLayout(False)
        Me.PerformLayout()

    End Sub
    Friend WithEvents Engineer As System.Windows.Forms.Button
    Friend WithEvents Production As System.Windows.Forms.Button
    Friend WithEvents Mode As System.Windows.Forms.TextBox
    Friend WithEvents Label2 As System.Windows.Forms.Label
    Friend WithEvents Label1 As System.Windows.Forms.Label
    Friend WithEvents textbox_ip As System.Windows.Forms.TextBox

End Class
