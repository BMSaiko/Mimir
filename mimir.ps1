# mimir — sticky-note todolist widget, Windows. PowerShell + WPF nativo.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$dataDir  = Join-Path $env:USERPROFILE '.mimir'
$dataFile = Join-Path $dataDir 'notas.json'

$script:notas = @()
if (Test-Path $dataFile) {
    try { $script:notas = @((Get-Content $dataFile -Raw | ConvertFrom-Json)) } catch {}
}

function Save-Notas {
    if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir | Out-Null }
    ($script:notas | ConvertTo-Json -Depth 3) | Set-Content $dataFile -Encoding UTF8
}
function Get-Note([string]$id) { $script:notas | Where-Object { $_.id -eq $id } | Select-Object -First 1 }
function Add-Note {
    $n = [pscustomobject]@{ id = [guid]::NewGuid().ToString('N').Substring(0,8); texto = ''; done = $false }
    $script:notas = @($n) + @($script:notas)
    Save-Notas; Render
    $newb = $null
    foreach ($ch in $List.Children) { if ($ch.Tag -eq $n.id) { $newb = $ch; break } }
    if ($newb) { $tb = $newb.Children[2]; if ($tb -is [System.Windows.Controls.TextBox]) { $tb.Focus() } }
}

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="mimir" WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" Topmost="True" ShowInTaskbar="False"
        Width="370" Height="520" Left="60" Top="60" ResizeMode="NoResize">
  <Window.Resources>
    <Style x:Key="FlatBtn" TargetType="Button">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Foreground" Value="#E6E6E6"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FontSize" Value="16"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="6">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="b" Property="Background" Value="#2B2D33"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>
  <Border CornerRadius="12" Background="#1E1F23" BorderBrush="#34363D" BorderThickness="1"
          SnapsToDevicePixels="True">
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
      </Grid.RowDefinitions>
      <DockPanel x:Name="Header" Background="#232428" LastChildFill="False" Height="46">
        <TextBlock DockPanel.Dock="Left" Text="&#5861; mimir" Foreground="#E6E6E6"
                   FontSize="15" FontWeight="Bold" VerticalAlignment="Center" Margin="14,0,0,0"/>
        <Button x:Name="AddBtn"   DockPanel.Dock="Right" Content="&#43;" Style="{StaticResource FlatBtn}"
                Foreground="#6EE7A0" Width="36" Height="30" Margin="0,8,2,8"/>
        <Button x:Name="CloseBtn" DockPanel.Dock="Right" Content="&#215;" Style="{StaticResource FlatBtn}"
                Foreground="#F07178" Width="36" Height="30" Margin="0,8,0,8"/>
      </DockPanel>
      <ScrollViewer x:Name="Scroller" Grid.Row="1" VerticalScrollBarVisibility="Auto"
                    HorizontalScrollBarVisibility="Disabled" Background="#1E1F23">
        <StackPanel x:Name="List" Margin="10,10,10,10"/>
      </ScrollViewer>
    </Grid>
  </Border>
</Window>
'@
$reader = New-Object System.Xml.XmlNodeReader $xaml
$win      = [System.Windows.Markup.XamlReader]::Load($reader)
$List     = $win.FindName('List')
$AddBtn   = $win.FindName('AddBtn')
$CloseBtn = $win.FindName('CloseBtn')
$Header   = $win.FindName('Header')

function New-NoteRow([pscustomobject]$n) {
    $row = New-Object System.Windows.Controls.DockPanel
    $row.Tag = $n.id
    $row.Margin = '0,2,0,3'
    $row.LastChildFill = $true

    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Tag = $n.id
    $cb.IsChecked = $n.done
    $cb.Margin = '4,8,10,0'
    $cb.VerticalAlignment = 'Top'
    $cb.Foreground = '#6EE7A0'
    [System.Windows.Controls.DockPanel]::SetDock($cb, 'Left')

    $del = New-Object System.Windows.Controls.Button
    $del.Tag = $n.id
    $del.Content = '&#215;'
    $del.Width = 24; $del.Height = 24
    $del.Margin = '6,6,2,0'
    $del.Foreground = '#F07178'
    $del.Background = 'Transparent'
    $del.BorderThickness = 0
    $del.FontSize = 14
    $del.Cursor = 'Hand'
    $del.ToolTip = 'Apagar nota'
    [System.Windows.Controls.DockPanel]::SetDock($del, 'Right')

    $txt = New-Object System.Windows.Controls.TextBox
    $txt.Tag = $n.id
    $txt.Text = $n.texto
    $txt.Background = '#232428'
    $txt.Foreground = '#E6E6E6'
    $txt.BorderThickness = 0
    $txt.FontSize = 13
    $txt.Padding = '8,7,8,7'
    $txt.Margin = '0,0,0,0'

    # --- toggle done: inline update, no full Render (evita recursao do IsChecked)
    $cb.Add_Checked({ param($s,$e)
        $nn = Get-Note $s.Tag
        if ($nn) { $nn.done = $true; Save-Notas; $s.Foreground = '#8B8E98' }
    })
    $cb.Add_Unchecked({ param($s,$e)
        $nn = Get-Note $s.Tag
        if ($nn) { $nn.done = $false; Save-Notas; $s.Foreground = '#6EE7A0' }
    })
    $del.Add_Click({ param($s,$e)
        $script:notas = @($script:notas | Where-Object { $_.id -ne $s.Tag })
        Save-Notas; Render
    })
    $txt.Add_TextChanged({ param($s,$e)
        $nn = Get-Note $s.Tag
        if ($nn) { $nn.texto = $s.Text; $nn.LastEdit = (Get-Date -Format o) }
    })
    $txt.Add_LostFocus({ Save-Notas })

    $row.AddChild($cb); $row.AddChild($del); $row.AddChild($txt)
    return $row
}

function Render {
    $List.Children.Clear()
    if ($script:notas.Count -eq 0) {
        $t = New-Object System.Windows.Controls.TextBlock
        $t.Text = 'Sem notas — plus para adicionar'
        $t.Foreground = '#8B8E98'; $t.Margin = '6,18,0,0'
        $List.Children.Add($t) | Out-Null
        return
    }
    foreach ($n in $script:notas) {
        $List.Children.Add((New-NoteRow $n)) | Out-Null
    }
}

$Header.Add_MouseLeftButtonDown({ try { $win.DragMove() } catch {} })
$AddBtn.Add_Click({ Add-Note })
$CloseBtn.Add_Click({ $win.Close() })

Render
[void]$win.ShowDialog()
