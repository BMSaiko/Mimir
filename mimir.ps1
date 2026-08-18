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
    if ($newb) { $tb = $newb.Children[0].Children[2]; if ($tb -is [System.Windows.Controls.TextBox]) { $tb.Focus() } }
}

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="mimir" WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" Topmost="True" ShowInTaskbar="False"
        Width="370" Height="520" Left="60" Top="60" ResizeMode="NoResize">
  <Window.Resources>
    <!-- paleta: bronze/ouro (poço de Mimir), carvão profundo -->
    <SolidColorBrush x:Key="bg"        Color="#141518"/>
    <SolidColorBrush x:Key="surface"   Color="#1D1F24"/>
    <SolidColorBrush x:Key="surface2"  Color="#262930"/>
    <SolidColorBrush x:Key="border"    Color="#2E3138"/>
    <SolidColorBrush x:Key="text"      Color="#E8E9EB"/>
    <SolidColorBrush x:Key="muted"     Color="#8B8E98"/>
    <SolidColorBrush x:Key="accent"    Color="#D4A24E"/>
    <SolidColorBrush x:Key="accent2"   Color="#E0B96A"/>
    <SolidColorBrush x:Key="danger"    Color="#E57A7A"/>

    <Style x:Key="FlatBtn" TargetType="Button">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Foreground" Value="{StaticResource muted}"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FontSize" Value="16"/>
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

    <!-- checkbox custom: caixa redonda, check dourado -->
    <Style TargetType="CheckBox">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="VerticalAlignment" Value="Top"/>
      <Setter Property="Margin" Value="4,7,10,0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Grid Width="19" Height="19" Background="Transparent">
              <Border x:Name="box" CornerRadius="5" BorderBrush="{StaticResource muted}"
                      BorderThickness="1.5" Background="Transparent"/>
              <Path x:Name="check" Data="M 4 10 L 7.8 13.5 L 15 6"
                    Stroke="#141518" StrokeThickness="2.4" Visibility="Collapsed"
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

    <!-- textbox: sem moldura, transparente -->
    <Style TargetType="TextBox">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="0"/>
      <Setter Property="Foreground" Value="{StaticResource text}"/>
      <Setter Property="FontSize" Value="13.5"/>
      <Setter Property="FontFamily" Value="Segoe UI"/>
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
        <RowDefinition Height="*"/>
      </Grid.RowDefinitions>

      <DockPanel Grid.Row="0" x:Name="Header" Background="{StaticResource surface}"
                 LastChildFill="False" Height="48">
        <!-- faixa de acento -->
        <Rectangle DockPanel.Dock="Left" Width="3" Fill="{StaticResource accent}"/>
        <StackPanel DockPanel.Dock="Left" Orientation="Horizontal" VerticalAlignment="Center" Margin="12,0,0,0">
          <TextBlock Text="ᛗ" Foreground="{StaticResource accent}" FontSize="17" FontWeight="Bold" Margin="0,0,7,0"/>
          <TextBlock Text="mimir" Foreground="{StaticResource text}" FontSize="15" FontWeight="SemiBold"/>
        </StackPanel>
        <Button x:Name="CloseBtn" DockPanel.Dock="Right" Content="✕" Style="{StaticResource FlatBtn}"
                Foreground="{StaticResource muted}" Width="34" Height="30" Margin="0,9,6,9"/>
        <Button x:Name="AddBtn"   DockPanel.Dock="Right" Content="＋" Style="{StaticResource FlatBtn}"
                Foreground="{StaticResource accent}" Width="34" Height="30" Margin="0,9,0,9"/>
      </DockPanel>

      <ScrollViewer Grid.Row="1" x:Name="Scroller" VerticalScrollBarVisibility="Auto"
                    HorizontalScrollBarVisibility="Disabled" Background="Transparent"
                    Padding="10,10,10,10">
        <StackPanel x:Name="List"/>
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

$TextDecor = [System.Windows.TextDecorations]::Strikethrough

function New-NoteRow([pscustomobject]$n) {
    $card = New-Object System.Windows.Controls.Border
    $card.Tag = $n.id
    $card.CornerRadius = [System.Windows.CornerRadius]::new(10)
    $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#1D1F24')
    $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#26292F')
    $card.BorderThickness = [System.Windows.Thickness]::new(1)
    $card.Padding = [System.Windows.Thickness]::new(10,5,4,5)
    $card.Margin = [System.Windows.Thickness]::new(0,0,0,7)
    $card.SnapsToDevicePixels = $true

    $row = New-Object System.Windows.Controls.DockPanel
    $row.LastChildFill = $true

    $del = New-Object System.Windows.Controls.Button
    $del.Tag = $n.id
    $del.Content = '✕'
    $del.Width = 22; $del.Height = 22
    $del.Margin = [System.Windows.Thickness]::new(4,6,0,0)
    $del.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#8B8E98')
    $del.Background = [System.Windows.Media.Brushes]::Transparent
    $del.BorderThickness = [System.Windows.Thickness]::new(0)
    $del.FontSize = 12
    $del.Cursor = [System.Windows.Input.Cursors]::Hand
    $del.ToolTip = 'Apagar nota'
    $del.Tag = $n.id
    [System.Windows.Controls.DockPanel]::SetDock($del, 'Right')

    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Tag = $n.id
    $cb.IsChecked = $n.done
    [System.Windows.Controls.DockPanel]::SetDock($cb, 'Left')

    $txt = New-Object System.Windows.Controls.TextBox
    $txt.Tag = $n.id
    $txt.Text = $n.texto
    $txt.Margin = [System.Windows.Thickness]::new(0,6,0,6)
    $txt.VerticalContentAlignment = 'Center'
    if ($n.done) { $txt.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#8B8E98'); $txt.TextDecorations = $TextDecor }

    # hover do card
    $card.Add_MouseEnter({ param($s,$e) $s.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D4A24E') })
    $card.Add_MouseLeave({ param($s,$e) $s.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#26292F') })

    $cb.Add_Checked({ param($s,$e)
        $nn = Get-Note $s.Tag
        if ($nn) { $nn.done = $true; Save-Notas }
        $t = $s.Parent.Children[2]
        $t.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#8B8E98')
        $t.TextDecorations = $TextDecor
    })
    $cb.Add_Unchecked({ param($s,$e)
        $nn = Get-Note $s.Tag
        if ($nn) { $nn.done = $false; Save-Notas }
        $t = $s.Parent.Children[2]
        $t.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#E8E9EB')
        $t.TextDecorations = $null
    })
    $del.Add_Click({ param($s,$e)
        $script:notas = @($script:notas | Where-Object { $_.id -ne $s.Tag })
        Save-Notas; Render
    })
    $txt.Add_TextChanged({ param($s,$e)
        $nn = Get-Note $s.Tag
        if ($nn) { $nn.texto = $s.Text }
    })
    $txt.Add_LostFocus({ Save-Notas })

    # strikethrough ao marcar (captura $txt no closure via $card)

    $row.AddChild($cb); $row.AddChild($del); $row.AddChild($txt)
    $card.Child = $row
    return $card
}

function Render {
    $List.Children.Clear()
    if ($script:notas.Count -eq 0) {
        $t = New-Object System.Windows.Controls.TextBlock
        $t.Text = 'Sem notas — ＋ para adicionar'
        $t.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#8B8E98')
        $t.Margin = [System.Windows.Thickness]::new(6,22,0,0)
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
