# mimir — sticky-note todolist widget, Windows. PowerShell + WPF nativo.
$ErrorActionPreference = 'Stop'
# ponytail: PS7 (pwsh) nao corre scriptblocks em callbacks Win32 (runspace-per-thread)
# -> re-exec em Windows PowerShell 5.1, que e o que o .lnk e o codigo assumem
if ($PSVersionTable.PSEdition -eq 'Core') {
    Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File', $PSCommandPath)
    exit
}
# ponytail: single-instance — 2a instancia sai logo (evita clobber no notas.json com last-write-wins)
$script:mimirMutex = New-Object System.Threading.Mutex($false, 'mimir_single_instance')
if (-not $script:mimirMutex.WaitOne(0, $false)) {
    [System.Windows.MessageBox]::Show('O Mimir ja esta a correr.','Mimir') | Out-Null
    exit
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class MimirHotkey {
  [DllImport("user32.dll")] public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint mods, uint vk);
}
"@

$dataDir  = Join-Path $env:USERPROFILE '.mimir'
$dataFile = Join-Path $dataDir 'notas.json'

$script:notas = @()
if (Test-Path $dataFile) {
    try { $script:notas = @((Get-Content $dataFile -Raw | ConvertFrom-Json)) } catch {}
}
# normaliza: garante prio e subs (PSCustomObject nao aceita property nova depois)
$script:notas = @($script:notas | ForEach-Object {
    $o = $_
    if (-not $o.PSObject.Properties['prio']) { $o | Add-Member -NotePropertyName prio -NotePropertyValue 'med' -Force }
    if (-not $o.PSObject.Properties['subs'])  { $o | Add-Member -NotePropertyName subs  -NotePropertyValue @() -Force }
    $o
})

function Save-Notas {
    if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir | Out-Null }
    ($script:notas | ConvertTo-Json -Depth 5) | Set-Content $dataFile -Encoding UTF8
}
function Get-Note([string]$id) { $script:notas | Where-Object { $_.id -eq $id } | Select-Object -First 1 }
function Add-Note {
    $n = [pscustomobject]@{ id=[guid]::NewGuid().ToString('N').Substring(0,8); texto=''; done=$false; prio='med'; subs=@() }
    # ponytail: prune notas abandonadas (vazias, sem subs, nao-done). Sempre depois de add — nunca em edicao ativa.
    $script:notas = @($script:notas | Where-Object { -not ([string]::IsNullOrWhiteSpace($_.texto) -and $_.subs.Count -eq 0 -and -not $_.done) })
    $script:notas = @($n) + @($script:notas)
    Save-Notas; Render
    foreach ($c in $List.Children) { if ($c.Tag -eq $n.id) { $tb = Find-ChildByType $c.Child 'System.Windows.Controls.TextBox'; if ($tb) { $tb.Focus() }; break } }
}
function Find-ChildByType($parent,$type) {
    foreach ($c in $parent.Children) {
        if ($c.GetType().FullName -eq $type) { return $c }
        if ($c -is [System.Windows.Controls.Panel] -and $c.Children.Count -gt 0) {
            $r = Find-ChildByType $c $type; if ($r) { return $r }
        }
    }
    return $null
}
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="mimir" WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" Topmost="True" ShowInTaskbar="False"
        Width="372" Height="520" ResizeMode="NoResize">
  <Window.Resources>
    <SolidColorBrush x:Key="bg"        Color="#141518"/>
    <SolidColorBrush x:Key="surface"   Color="#1D1F24"/>
    <SolidColorBrush x:Key="surface2"  Color="#262930"/>
    <SolidColorBrush x:Key="border"    Color="#2E3138"/>
    <SolidColorBrush x:Key="text"      Color="#E8E9EB"/>
    <SolidColorBrush x:Key="muted"     Color="#8B8E98"/>
    <SolidColorBrush x:Key="accent"    Color="#D4A24E"/>
    <SolidColorBrush x:Key="danger"    Color="#E57A7A"/>

    <Style x:Key="FlatBtn" TargetType="Button">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Foreground" Value="{StaticResource muted}"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="7">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="b" Property="Background" Value="{StaticResource surface2}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="CheckBox">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="VerticalAlignment" Value="Top"/>
      <Setter Property="Margin" Value="4,5,8,0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Grid Width="18" Height="18" Background="Transparent">
              <Border x:Name="box" CornerRadius="5" BorderBrush="{StaticResource muted}"
                      BorderThickness="1.5" Background="Transparent"/>
              <Path x:Name="check" Data="M 4 9.5 L 7.5 13 L 14.5 5.5"
                    Stroke="#141518" StrokeThickness="2.3" Visibility="Collapsed"
                    StrokeEndLineCap="Round" StrokeStartLineCap="Round"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="box" Property="Background" Value="{StaticResource accent}"/>
                <Setter TargetName="box" Property="BorderBrush" Value="{StaticResource accent}"/>
                <Setter TargetName="check" Property="Visibility" Value="Visible"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="box" Property="BorderBrush" Value="{StaticResource accent}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="TextBox">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="0"/>
      <Setter Property="Foreground" Value="{StaticResource text}"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="FontFamily" Value="Segoe UI"/>
      <Style.Triggers>
        <Trigger Property="IsKeyboardFocusWithin" Value="True">
          <Setter Property="Background" Value="{StaticResource surface2}"/>
          <Setter Property="FontWeight" Value="SemiBold"/>
        </Trigger>
      </Style.Triggers>
    </Style>
  </Window.Resources>

  <Border CornerRadius="14" Background="{StaticResource bg}" BorderBrush="{StaticResource border}"
          BorderThickness="1" SnapsToDevicePixels="True">
    <Border.Effect>
      <DropShadowEffect BlurRadius="26" ShadowDepth="0" Opacity="0.55" Color="#000000"/>
    </Border.Effect>
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
      </Grid.RowDefinitions>

      <DockPanel Grid.Row="0" x:Name="Header" Background="{StaticResource surface}"
                 LastChildFill="False" Height="48">
        <Rectangle DockPanel.Dock="Left" Width="3" Fill="{StaticResource accent}"/>
        <StackPanel DockPanel.Dock="Left" Orientation="Horizontal" VerticalAlignment="Center" Margin="12,0,0,0">
          <TextBlock Text="ᛗ" Foreground="{StaticResource accent}" FontSize="17" FontWeight="Bold" Margin="0,0,7,0" FontFamily="Segoe UI Historic"/>
          <TextBlock Text="mimir" Foreground="{StaticResource text}" FontSize="15" FontWeight="SemiBold"/>
        </StackPanel>
        <Button x:Name="CloseBtn" DockPanel.Dock="Right" Content="×" Style="{StaticResource FlatBtn}"
                Foreground="{StaticResource muted}" Width="34" Height="30" Margin="0,9,6,9"/>
        <Button x:Name="AddBtn"   DockPanel.Dock="Right" Content="+" Style="{StaticResource FlatBtn}"
                Foreground="{StaticResource accent}" Width="34" Height="30" Margin="0,9,0,9"/>
        <TextBlock x:Name="DoneText" DockPanel.Dock="Right" VerticalAlignment="Center"
                   Foreground="{StaticResource muted}" FontSize="12" Margin="0,0,14,0"/>
      </DockPanel>

      <ProgressBar Grid.Row="1" x:Name="Progress" Height="3" Minimum="0" Maximum="1"
                   Foreground="{StaticResource accent}" Background="{StaticResource surface2}"
                   BorderThickness="0" Margin="10,0,10,0"/>

      <ScrollViewer Grid.Row="2" x:Name="Scroller" VerticalScrollBarVisibility="Auto"
                    HorizontalScrollBarVisibility="Disabled" Background="Transparent"
                    Padding="10,10,10,10">
        <StackPanel x:Name="List"/>
      </ScrollViewer>
    </Grid>
  </Border>
</Window>
'@
$reader = New-Object System.Xml.XmlNodeReader $xaml
$win       = [System.Windows.Markup.XamlReader]::Load($reader)
$List      = $win.FindName('List')
$AddBtn    = $win.FindName('AddBtn')
$CloseBtn  = $win.FindName('CloseBtn')
$Header    = $win.FindName('Header')
$DoneText  = $win.FindName('DoneText')
$Progress  = $win.FindName('Progress')

$TextDecor = [System.Windows.TextDecorations]::Strikethrough
$PrioColor = @{ low='#6EA8FE'; med='#F9C74F'; high='#F07178' }
$PrioColorHex = @{ low='6EA8FE'; med='F9C74F'; high='F07178' }

function Move-CardLast([object]$card) {
    # ponytail: done demote sem rebuild — remove e re-insere no fim (evita recursao de Render no toggle)
    $List.Children.Remove($card); $List.Children.Add($card) | Out-Null
}
function Move-CardToActive([object]$card) {
    # ponytail: volta a por o card antes do primeiro done; ordem ativa preservada
    $List.Children.Remove($card)
    $i = 0
    foreach ($c in $List.Children) { if ($c.Tag -and (Get-Note $c.Tag).done) { break }; $i++ }
    if ($i -ge $List.Children.Count) { $List.Children.Add($card) | Out-Null } else { $List.Children.Insert($i, $card) }
}

function New-SubRow([pscustomobject]$n, [pscustomobject]$sub, [System.Windows.Controls.StackPanel]$subsHost) {
    $sr = New-Object System.Windows.Controls.DockPanel
    $sr.LastChildFill = $true

    $schk = New-Object System.Windows.Controls.CheckBox
    $schk.Tag = @($n.id, $sub.id)
    $schk.IsChecked = $sub.done
    [System.Windows.Controls.DockPanel]::SetDock($schk,'Left')

    $stxt = New-Object System.Windows.Controls.TextBox
    $stxt.Tag = @($n.id, $sub.id)
    $stxt.Text = $sub.texto
    $stxt.Margin = [System.Windows.Thickness]::new(0,2,0,2)
    if ($sub.done) { $stxt.Foreground=[System.Windows.Media.BrushConverter]::new().ConvertFromString('#8B8E98'); $stxt.TextDecorations=$TextDecor }

    $sdel = New-Object System.Windows.Controls.Button
    $sdel.Content = '×'
    $sdel.Tag = @($n.id, $sub.id)
    $sdel.Width=18; $sdel.Height=18; $sdel.FontSize=11
    $sdel.Foreground=[System.Windows.Media.BrushConverter]::new().ConvertFromString('#E57A7A')
    $sdel.Background=[System.Windows.Media.Brushes]::Transparent
    $sdel.BorderThickness=[System.Windows.Thickness]::new(0)
    $sdel.Cursor=[System.Windows.Input.Cursors]::Hand
    [System.Windows.Controls.DockPanel]::SetDock($sdel,'Right')

    $schk.Add_Checked({ param($s,$e)
        $nid,$sid = $s.Tag
        $nn = Get-Note $nid; if (-not $nn) { return }
        $ss = $nn.subs | Where-Object { $_.id -eq $sid } | Select-Object -First 1
        if ($ss) { $ss.done=$true; Save-Notas }
        if ($s.Parent) { $stb = Find-ChildByType $s.Parent 'System.Windows.Controls.TextBox'; if ($stb) { $stb.Foreground=[System.Windows.Media.BrushConverter]::new().ConvertFromString('#8B8E98'); $stb.TextDecorations=$TextDecor } }
    })
    $schk.Add_Unchecked({ param($s,$e)
        $nid,$sid = $s.Tag
        $nn = Get-Note $nid; if (-not $nn) { return }
        $ss = $nn.subs | Where-Object { $_.id -eq $sid } | Select-Object -First 1
        if ($ss) { $ss.done=$false; Save-Notas }
        if ($s.Parent) { $stb = Find-ChildByType $s.Parent 'System.Windows.Controls.TextBox'; if ($stb) { $stb.Foreground=[System.Windows.Media.BrushConverter]::new().ConvertFromString('#8B8E98') -as [System.Windows.Media.Brush]; $stb.TextDecorations=$null } }
    })
    $sdel.Add_Click({ param($s,$e)
        $nid,$sid = $s.Tag
        $nn = Get-Note $nid; if (-not $nn) { return }
        $nn.subs = @($nn.subs | Where-Object { $_.id -ne $sid })
        Save-Notas; Render
    })
    $stxt.Add_TextChanged({ param($s,$e)
        $nid,$sid = $s.Tag
        $nn = Get-Note $nid; if (-not $nn) { return }
        $ss = $nn.subs | Where-Object { $_.id -eq $sid } | Select-Object -First 1
        if ($ss) { $ss.texto = $s.Text }
        $script:saveTimer.Stop(); $script:saveTimer.Start()
    })
    $stxt.Add_LostFocus({ Save-Notas })

    $sr.AddChild($schk); $sr.AddChild($sdel); $sr.AddChild($stxt)  # ponytail: textbox ultimo = LastChildFill
    return $sr
}

function New-NoteRow([pscustomobject]$n) {
    $card = New-Object System.Windows.Controls.Border
    $card.Tag = $n.id
    $card.CornerRadius = [System.Windows.CornerRadius]::new(10)
    $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#1D1F24')
    $card.BorderThickness = [System.Windows.Thickness]::new(1)
    $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString(($PrioColor[$n.prio]))
    $card.Padding = [System.Windows.Thickness]::new(10,5,4,5)
    $card.Margin = [System.Windows.Thickness]::new(0,0,0,7)
    $card.SnapsToDevicePixels = $true

    # content: vertical stack = [main row][subs host]
    $stack = New-Object System.Windows.Controls.StackPanel

    $row = New-Object System.Windows.Controls.DockPanel
    $row.LastChildFill = $true

    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Tag = $n.id
    $cb.IsChecked = $n.done
    [System.Windows.Controls.DockPanel]::SetDock($cb,'Left')

    $txt = New-Object System.Windows.Controls.TextBox
    $txt.Tag = $n.id
    $txt.Text = $n.texto
    $txt.Margin = [System.Windows.Thickness]::new(0,4,0,4)
    $txt.VerticalContentAlignment = 'Center'
    if ($n.done) { $txt.Foreground=[System.Windows.Media.BrushConverter]::new().ConvertFromString('#8B8E98'); $txt.TextDecorations=$TextDecor }

    # actions: prio dots + subtask toggle + delete
    $act = New-Object System.Windows.Controls.StackPanel
    $act.Orientation = 'Horizontal'
    $act.Margin = [System.Windows.Thickness]::new(6,0,0,0)
    foreach ($p in @('low','med','high')) {
        $dot = New-Object System.Windows.Controls.Button
        $dot.Width=10; $dot.Height=10; $dot.Margin=[System.Windows.Thickness]::new(0,0,5,0)
        $dot.Tag = @($n.id,$p)
        $dot.ToolTip = $p
        $dot.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString(($PrioColor[$p]))
        $dot.BorderThickness = [System.Windows.Thickness]::new(0)
        $dot.Cursor = [System.Windows.Input.Cursors]::Hand
        $dot.Add_Click({ param($s,$e)
            $nid,$pp = $s.Tag
            $nn = Get-Note $nid; if (-not $nn) { return }
            $nn.prio = $pp; Save-Notas; Render
        })
        $dot.Add_MouseEnter({ param($s,$e) $s.Width=13; $s.Height=13 })
        $dot.Add_MouseLeave({ param($s,$e) $s.Width=10; $s.Height=10 })
        $act.AddChild($dot) | Out-Null
    }
    $del = New-Object System.Windows.Controls.Button
    $del.Content = '×'
    $del.Width=22; $del.Height=22; $del.FontSize=12
    $del.Margin=[System.Windows.Thickness]::new(0,0,0,0)
    $del.Tag = $n.id
    $del.Foreground=[System.Windows.Media.BrushConverter]::new().ConvertFromString('#8B8E98')
    $del.Background=[System.Windows.Media.Brushes]::Transparent
    $del.BorderThickness=[System.Windows.Thickness]::new(0)
    $del.Cursor=[System.Windows.Input.Cursors]::Hand
    $del.ToolTip='Apagar nota'
    $act.AddChild($del) | Out-Null
    [System.Windows.Controls.DockPanel]::SetDock($act,'Right')

    # subs host (collapsed, preenchido on toggle)
    $subsHost = New-Object System.Windows.Controls.StackPanel
    $subsHost.Margin = [System.Windows.Thickness]::new(26,2,0,2)
    $subsHost.Visibility = 'Collapsed'

    $row.AddChild($cb); $row.AddChild($act); $row.AddChild($txt)
    $stack.AddChild($row) | Out-Null
    $stack.AddChild($subsHost) | Out-Null
    $card.Child = $stack

    $card.Add_MouseEnter({ param($s,$e) $s.Opacity = 1.0 })
    $card.Add_MouseLeave({ param($s,$e) $s.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString(($PrioColor[((Get-Note $s.Tag).prio)])) })

    # subtask toggle button: colocado no action trailing
    $subBtn = New-Object System.Windows.Controls.Button
    $subBtn.Content = '+'
    $subBtn.Width=22; $subBtn.Height=22; $subBtn.FontSize=12
    $subBtn.Margin=[System.Windows.Thickness]::new(0,0,4,0)
    $subBtn.Tag = $n.id
    $subBtn.Foreground=[System.Windows.Media.BrushConverter]::new().ConvertFromString('#8B8E98')
    $subBtn.Background=[System.Windows.Media.Brushes]::Transparent
    $subBtn.BorderThickness=[System.Windows.Thickness]::new(0)
    $subBtn.Cursor=[System.Windows.Input.Cursors]::Hand
    $subBtn.ToolTip='Sub-tarefas'
    $subBtn.Add_Click({ param($s,$e)
        # walk visual tree: btn->act->row->stack ; subsHost = stack.Children[1]
        $stack = $s.Parent.Parent.Parent
        $host_ = $stack.Children[1]
        $nn = Get-Note $s.Tag
        if (-not $nn) { return }
        if ($host_.Visibility -eq 'Collapsed') {
            if ($nn.subs.Count -eq 0) { $nn.subs = @([pscustomobject]@{ id=[guid]::NewGuid().ToString('N').Substring(0,8); texto=''; done=$false }); Save-Notas }
            $host_.Children.Clear()
            foreach ($sub in $nn.subs) { $host_.Children.Add((New-SubRow $nn $sub $host_)) | Out-Null }
            $host_.Visibility = 'Visible'
            $s.Content = '-'
        } else {
            $host_.Visibility = 'Collapsed'
            $s.Content = '+'
        }
    })
    $act.Children.Insert(0, $subBtn) | Out-Null

    # toggle done + edits
    $cb.Add_Checked({ param($s,$e)
        $nn = Get-Note $s.Tag
        if ($nn) { $nn.done=$true; Save-Notas; Update-Progress }
        if ($s.Parent) { $tbx = Find-ChildByType $s.Parent 'System.Windows.Controls.TextBox'; if ($tbx) { $tbx.Foreground=[System.Windows.Media.BrushConverter]::new().ConvertFromString('#8B8E98'); $tbx.TextDecorations=$TextDecor }
            # ponytail: NAO usar closure $card (scriptblock de evento nao captura local da funcao -> $null)
            $c = $List.Children | Where-Object { $_.Tag -eq $s.Tag } | Select-Object -First 1
            if ($c) { Move-CardLast $c } }
    })
    $cb.Add_Unchecked({ param($s,$e)
        $nn = Get-Note $s.Tag
        if ($nn) { $nn.done=$false; Save-Notas; Update-Progress }
        if ($s.Parent) { $tbx = Find-ChildByType $s.Parent 'System.Windows.Controls.TextBox'; if ($tbx) { $tbx.Foreground=[System.Windows.Media.BrushConverter]::new().ConvertFromString('#E8E9EB'); $tbx.TextDecorations=$null }
            $c = $List.Children | Where-Object { $_.Tag -eq $s.Tag } | Select-Object -First 1
            if ($c) { Move-CardToActive $c } }
    })
    $txt.Add_TextChanged({ param($s,$e)
        $nn = Get-Note $s.Tag
        if ($nn) { $nn.texto = $s.Text }
        $script:saveTimer.Stop(); $script:saveTimer.Start()
    })
    $del.Add_Click({ param($s,$e)
        $script:notas = @($script:notas | Where-Object { $_.id -ne $s.Tag })
        Save-Notas; Render
    })
    $txt.Add_LostFocus({ Save-Notas })

    return $card
}

function Update-Progress {
    # ponytail: counters barra+texto — chamada no Render e nos toggles de done (evita rebuild da lista)
    $d = @($script:notas | Where-Object { $_.done }).Count
    $DoneText.Text = if ($script:notas.Count) { "$d/$($script:notas.Count)" } else { '' }
    # ponytail: Maximum clamped a 1 para o ProgressBar nao rebentar com 0 notas
    $Progress.Maximum = [Math]::Max(1, $script:notas.Count)
    $Progress.Value   = if ($script:notas.Count) { $d } else { 0 }
}

function Render {
    $List.Children.Clear()
    Update-Progress
    if ($script:notas.Count -eq 0) {
        $t = New-Object System.Windows.Controls.TextBlock
        $t.Text = 'Sem notas — + para adicionar'
        $t.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#8B8E98')
        $t.Margin = [System.Windows.Thickness]::new(6,22,0,0)
        $List.Children.Add($t) | Out-Null
        return
    }
    # ponytail: done demote — só a ordem de exibicao, nunca muta $script:notas (ordem de criacao preservada no JSON)
    $order = @($script:notas | Where-Object { -not $_.done }) + @($script:notas | Where-Object { $_.done })
    foreach ($n in $order) {
        $List.Children.Add((New-NoteRow $n)) | Out-Null
    }
}

$Header.Add_MouseLeftButtonDown({ try { $win.DragMove() } catch {} })
$AddBtn.Add_Click({ Add-Note })
$CloseBtn.Add_Click({ Save-Notas; $script:mimirMutex.ReleaseMutex(); $win.Close() })
# ponytail: Enter=add nota, Esc=commit/blur (so quando um TextBox tem foco)
$win.Add_KeyDown({ param($s,$e)
    if ($e.OriginalSource -is [System.Windows.Controls.TextBox]) {
        if ($e.Key -eq [System.Windows.Input.Key]::Return)  { $e.Handled=$true; Add-Note }
        elseif ($e.Key -eq [System.Windows.Input.Key]::Escape) { $e.Handled=$true; Save-Notas; $win.Focus() }
    }
})

$win.Add_Closing({ if ($script:mimirMutex) { try { $script:mimirMutex.ReleaseMutex() } catch {} } })
$win.Add_SourceInitialized({
    $h = (New-Object System.Windows.Interop.WindowInteropHelper($win)).Handle
    $src = [System.Windows.Interop.HwndSource]::FromHwnd($h)
    $src.AddHook({
        param($hwnd,$msg,$w,$l,$handled)
        if ($msg -eq 0x0312) {
            if ($win.IsVisible) { $win.Hide() } else { $win.Show() }
            $handled = $true
        }
        return [IntPtr]::Zero
    })
    $hk = [MimirHotkey]::RegisterHotKey($h, 1, 0x0, 0x73)  # F4
    # ponytail: se F4 ja pertence a outra app, loga e segue (app ainda funciona via botoes)
    if (-not $hk) { Add-Content $crashLog "HOTKEY: F4 ja registado por outra app" }
})
Add-Type -AssemblyName System.Windows.Forms
$pos = [System.Windows.Forms.Cursor]::Position
$area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$w = 372; $h = 40
$win.Left = [Math]::Max($area.Left, [Math]::Min($pos.X - $w/2, $area.Right - $w))
$win.Top  = [Math]::Max($area.Top,  [Math]::Min($pos.Y - 20,  $area.Bottom - $h))# ponytail: T1 debounce de save — regrava 1.2s apos 1a tecla silenciosa, evita perda ao fechar
$script:saveTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:saveTimer.Interval = [TimeSpan]::FromMilliseconds(1200)
$script:saveTimer.Add_Tick({ $script:saveTimer.Stop(); Save-Notas })

Prune-Empty   # ponytail: limpa vazios de sessoes antigas (T20) — chamada apos defs
Render
# ponytail: excecao de handler nao propaga ao callba nao propaga ao callbak nativo (matava a janela silenciosamente)
$ErrorActionPreference = 'Continue'
$crashLog = 'C:/Users/bruno/AppData/Local/Temp/mimir_crash.txt'
$win.Dispatcher.add_UnhandledException({
    param($sender, $e)
    Add-Content $crashLog ("CRASH: " + $e.Exception.ToString())
    Add-Content $crashLog ("STACK: " + $e.Exception.StackTrace)
    $e.Handled = $true
})
$win.Show()
[System.Windows.Threading.Dispatcher]::Run()
