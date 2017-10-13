Param (
    [String] $ServerName = "localhost",
    [Int] $ServerPort = 6667,
    [String] $BotNick = "boredBOT",
    [String] $BotUser = "boredBOT",
    [String] $BotName = "I am a bot, built from boredom"
)

# just some global types
$Buffer = New-Object System.Byte[] 4096
$Encoding = New-Object System.Text.AsciiEncoding

# send data to the server
Function Send-Text ($Text) {
    Write-Debug "<-- $Text"
    $Writer.WriteLine($Text)
}

# connect and run
Function Start-Bot {
    Try {
        $Script:Connection = New-Object System.Net.Sockets.TcpClient($ServerName, $ServerPort)
        $Script:Stream = $Connection.GetStream()
        $Script:Reader = New-Object System.IO.StreamReader($Stream)
        $Script:Writer = New-Object System.IO.StreamWriter($Stream)
        $Script:Writer.AutoFlush = $true

        # make sure the connection is still there (and not disconnected straight away)
        Write-Host "> Sending login instruction.."
        Send-Text "NICK $BotNick"
        Send-Text "USER $BotUser {} {} :$BotName"
        Start-Sleep -m 1000
        
        # loop until we die?
        While (1) {
            If ($Stream.DataAvailable) {
                $Read = $Encoding.GetString($Buffer, 0, $Stream.Read($Buffer, 0, 4096)).Trim().Split("`r")
                ForEach ($Line in $Read) {
                    $Line = $Line.Trim() # sanitise the string
                    Write-Debug "--> $Line"
                    $Text = $Line.Split(" ")
    
                    If ($Text[0] -like "*!*@*") {
                        ($Nick, $UHost) = $Text[0].Replace("!", " ").Substring(1).Split(" ")
                        $Target = $Text[2].TrimStart(":")
                        $Cmd = $Text[1]
                        If (!$Text[3] -eq $Null) {
                            $Text[3] = $Text[3].TrimStart(":")
                        }
                        Process-UserCommand $Nick $UHost $Target $Cmd $Text[3..$Text.Length]
                
                    } ElseIf ($Text[0].StartsWith(":")) {
                        Process-ServerCommands $Text

                    } Else {
                        Process-ServerDirect $Text
                    }
                }
            }
            Start-Sleep -m 10
        }
    
        $Reader.Close()
        $Writer.Close()
        $Connection.Close()

    } Catch {
        Write-Host "% Unable to connect to server."
    }
}

Function Process-CMessage($Nick, $UHost, $Chan, $Msg) {
    Write-Host "<$Nick($UHost):$Chan)> $Msg"
}

Function Process-UMessage($Nick, $Uhost, $Msg) {
    Write-Host "<$Nick($Uhost)> $Msg"
}

Function Process-CNotice($Nick, $Uhost, $Chan, $Msg) {
    Write-Host "-$Nick($Uhost):$chan- $Msg"
}

Function Process-Join($Nick, $Uhost, $Chan) {
    Write-Host "*** $Nick ($Uhost) joined $Chan"
}

Function Process-Part($Nick, $Uhost, $Chan, $Msg) {
    Write-Host "*** $Nick ($Uhost) parted $Chan ($Msg)"
}

Function Process-Quit($Nick, $Uhost, $Msg) {
    Write-Host "*** $Nick ($Uhost) quit IRC ($Msg)"
}

Function Process-Kick($Nick, $Uhost, $Chan, $Knick, $Msg) {
    Write-Host "*** $KNick was kicked from $Chan by $Nick ($Uhost) ($Msg)"
}

Function Process-Nick($Nick, $Uhost, $NewNick) {
    Write-Host "*** $Nick ($Uhost) is now known as $NewNick"
}

Function Process-UserCommand($Nick, $UHost, $Target, $Cmd, $Text) {
    Switch ($Cmd) {
        "PRIVMSG" {
            If ($Target.StartsWith("#")) {
                Process-CMessage $Nick $UHost $Target $Text
            } Else {
                Process-UMessage $Nick $UHost $Text
            }
        }
        "NOTICE" {
            If ($Target.StartsWith("#")) {
                Process-CNotice $Nick $UHost $Target $Text
            } Else {
                Process-UNotice $Nick $UHost $Target $Text
            }
        }
        "JOIN" {
            Process-Join $Nick $UHost $Target
        }
        "PART" {
            Process-Part $Nick $UHost $Target $Text
        }
        "QUIT" {
            Process-Quit $Nick $Uhost $Target $Text
        }
        "KICK" {
            $Text[1] = $Text[1].Substring(1)
            Process-Kick $Nick $Uhost $Target $Text[0] $Text[1..$Text.Length]
        }
        "NICK" {
            Process-Nick $Nick $Uhost $Target $Text
        }
    }
}

Function Process-ServerCommands($Text) {
    $Server = $Text[0].Substring(1)
    $Cmd = $Text[1]
    $Nick = $Text[2]
    $Text = $Text[3..$Text.Length]

    Switch ($Cmd) {
        "001" {
            Send-Text "JOIN #nictitate"
        }
    }
}

Function Process-ServerDirect($Text) {
    Switch ($Text[0]) {
        "PING" {
            Send-Text "PONG {0}" -f $Text[1]
        }
        "ERROR" {
            Write-Host "We have encountered an error, abort, abort!"
        }
    }
}

$DebugPreference = "Continue"

Start-Bot -Debug $True
