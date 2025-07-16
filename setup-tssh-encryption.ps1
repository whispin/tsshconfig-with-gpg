# 修改 Scoop 安装的 tssh 增强安装器
param(
    [switch]$Reset,
    [switch]$Install
)

$ErrorActionPreference = "Stop"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# 获取 Scoop 安装路径
function Get-ScoopPath {
    # 用户个人安装
    if (Test-Path "$env:USERPROFILE\scoop") {
        return "$env:USERPROFILE\scoop"
    }
    
    # 检查全局安装 - 检查可能的位置
    $globalPaths = @(
        "$env:ProgramData\scoop",
        "D:\scoop-global",
        "C:\scoop",
        "$env:SCOOP_GLOBAL"
    )
    
    foreach ($path in $globalPaths) {
        if ($path -and (Test-Path $path)) {
            return $path
        }
    }
    
    # 尝试从环境变量获取
    if ($env:SCOOP) {
        return $env:SCOOP
    }
    
    return $null
}

# 查找 tssh 的真实安装路径
function Find-ScoopTsshPath {
    # 获取所有可能的 Scoop 路径
    $scoopPaths = @()
    
    if (Test-Path "$env:USERPROFILE\scoop") {
        $scoopPaths += "$env:USERPROFILE\scoop"
    }
    
    $globalPaths = @(
        "$env:ProgramData\scoop",
        "D:\scoop-global",
        "C:\scoop"
    )
    
    foreach ($path in $globalPaths) {
        if (Test-Path $path) {
            $scoopPaths += $path
        }
    }
    
    if (!$scoopPaths) {
        Write-ColorOutput "未找到任何 Scoop 安装路径" "Red"
        return $null
    }
    
    # 在每个 Scoop 路径中查找 tssh
    foreach ($scoopPath in $scoopPaths) {
        Write-ColorOutput "检查 Scoop 路径: $scoopPath" "Blue"
        
        # 检查 current 符号链接
        $tsshCurrentPath = "$scoopPath\apps\tssh\current"
        if (Test-Path "$tsshCurrentPath\tssh.exe") {
            Write-ColorOutput "找到 current 路径: $tsshCurrentPath" "Green"
            return $tsshCurrentPath
        }
        
        # 检查 current 是否是符号链接，获取真实路径
        if (Test-Path $tsshCurrentPath) {
            $item = Get-Item $tsshCurrentPath
            if ($item.LinkType -eq "SymbolicLink" -and $item.Target) {
                $realPath = $item.Target[0]
                if (Test-Path "$realPath\tssh.exe") {
                    Write-ColorOutput "通过符号链接指向: $realPath" "Green"
                    return $realPath
                }
            }
        }
        
        # 查找版本目录
        $appsPath = "$scoopPath\apps\tssh"
        if (Test-Path $appsPath) {
            Write-ColorOutput "检查版本目录: $appsPath" "Blue"
            $versions = Get-ChildItem $appsPath -Directory | Where-Object { $_.Name -ne "current" }
            foreach ($version in $versions) {
                Write-ColorOutput "检查版本: $($version.Name)" "Yellow"
                if (Test-Path "$($version.FullName)\tssh.exe") {
                    Write-ColorOutput "找到 tssh.exe: $($version.FullName)" "Green"
                    return $version.FullName
                }
            }
        }
    }
    
    # 如果都没找到，尝试通过 shim 找到真实路径
    Write-ColorOutput "通过 shim 查找真实路径..." "Yellow"
    $tsshCmd = Get-Command tssh.exe -ErrorAction SilentlyContinue
    if ($tsshCmd -and $tsshCmd.Source -like "*shims*") {
        # 读取 shim 文件内容
        $shimContent = Get-Content $tsshCmd.Source -ErrorAction SilentlyContinue
        foreach ($line in $shimContent) {
            if ($line -match 'path\s*=\s*"([^"]+)"' -or $line -match "path\s*=\s*'([^']+)'") {
                $realPath = $matches[1]
                if (Test-Path $realPath) {
                    $realDir = Split-Path $realPath
                    Write-ColorOutput "从 shim 找到真实路径: $realDir" "Green"
                    return $realDir
                }
            }
        }
    }
    
    return $null
}

Write-ColorOutput "Scoop tssh 增强安装器修改程序" "Cyan"

# 查找 Scoop 和 tssh
$scoopPath = Get-ScoopPath
if (!$scoopPath) {
    Write-ColorOutput "未找到 Scoop 安装" "Red"
    exit 1
}

$tsshRealPath = Find-ScoopTsshPath
if (!$tsshRealPath) {
    Write-ColorOutput "未找到 Scoop 安装的 tssh" "Red"
    Write-ColorOutput "请运行: scoop install tssh" "Blue"
    exit 1
}

Write-ColorOutput "找到 tssh 真实路径: $tsshRealPath" "Green"

$shimPath = "$scoopPath\shims\tssh.exe"
$originalExe = "$tsshRealPath\tssh.exe"
$backupExe = "$tsshRealPath\tssh-original.exe"

# 重置到原始状态
if ($Reset) {
    Write-ColorOutput "重置 tssh 到原始状态..." "Yellow"
    
    # 删除加密的安装文件
    $filesToRemove = @(
        "$tsshRealPath\tssh.ps1",
        "$tsshRealPath\tssh.bat",
        "$tsshRealPath\tssh-wrapper.exe",
        "$tsshRealPath\tssh-wrapper.go"
    )
    
    foreach ($file in $filesToRemove) {
        if (Test-Path $file) {
            Remove-Item $file -Force
            Write-ColorOutput "删除: $file" "Yellow"
        }
    }
    
    # 恢复原始程序
    if (Test-Path $backupExe) {
        Copy-Item $backupExe $originalExe -Force
        Write-ColorOutput "恢复原始 tssh.exe" "Green"
    }
    
    # 重新安装 tssh 确保 shim 正确
    Write-ColorOutput "重新安装 tssh..." "Yellow"
    scoop uninstall tssh
    scoop install tssh
    
    Write-ColorOutput "重置完成！" "Green"
    return
}

# 安装增强安装器
if ($Install) {
    Write-ColorOutput "安装 tssh 增强安装器..." "Yellow"
    
    # 1. 检查依赖
    if (!(Get-Command gpg -ErrorAction SilentlyContinue)) {
        Write-ColorOutput "未找到 GPG，正在安装..." "Yellow"
        scoop install gpg
    }
    
    # 2. 备份原始程序
    if (!(Test-Path $backupExe)) {
        Copy-Item $originalExe $backupExe -Force
        Write-ColorOutput "备份原始程序" "Green"
    }
    
    # 3. 检查配置文件
    $configDir = "$env:USERPROFILE\.ssh"
    $configFile = "$configDir\config"
    $gpgFile = "$configDir\config.gpg"
    
    if (!(Test-Path $configFile) -and !(Test-Path $gpgFile)) {
        Write-ColorOutput "未找到 tssh 配置文件，请先创建配置" "Red"
        Write-ColorOutput "运行 'tssh' 命令进行初始设置，然后重新运行此脚本" "Blue"
        exit 1
    }
    
    # 4. 加密配置文件
    if (Test-Path $configFile) {
        if (!(Test-Path $gpgFile)) {
            Write-ColorOutput "加密配置文件..." "Yellow"
            
            # 检查 GPG 密钥
            $keys = gpg --list-keys 2>$null
            if (!$keys) {
                Write-ColorOutput "正在生成 GPG 密钥..." "Yellow"
                Write-ColorOutput "请按提示输入相关信息（建议使用强密码）" "Blue"
                gpg --gen-key
            }
            
            # 加密
            gpg --symmetric --cipher-algo AES256 --output $gpgFile $configFile
            
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "配置文件加密成功" "Green"
                Move-Item $configFile "$configFile.backup" -Force
            } else {
                Write-ColorOutput "配置文件加密失败" "Red"
                exit 1
            }
        } else {
            Write-ColorOutput "配置文件已加密" "Green"
        }
    }
    
    # 5. 生成 Go 包装程序
    Write-ColorOutput "生成包装程序..." "Yellow"
    
    $goCode = @'
package main

import (
    "fmt"
    "io/ioutil"
    "os"
    "os/exec"
    "path/filepath"
    "syscall"
    "time"
)

func main() {
    // 获取当前程序所在目录
    exePath, err := os.Executable()
    if err != nil {
        fmt.Fprintf(os.Stderr, "获取程序路径失败: %v\n", err)
        os.Exit(1)
    }
    exeDir := filepath.Dir(exePath)
    
    // 配置路径
    homeDir, _ := os.UserHomeDir()
    configDir := filepath.Join(homeDir, ".ssh")
    gpgFile := filepath.Join(configDir, "config.gpg")
    configFile := filepath.Join(configDir, "config")
    backupFile := filepath.Join(configDir, "config.bak")
    originalTssh := filepath.Join(exeDir, "tssh-original.exe")

    // 检查文件
    if _, err := os.Stat(gpgFile); os.IsNotExist(err) {
        fmt.Fprintf(os.Stderr, "无法找到加密的配置文件 %s\n", gpgFile)
        os.Exit(1)
    }

    if _, err := os.Stat(originalTssh); os.IsNotExist(err) {
        fmt.Fprintf(os.Stderr, "无法找到原始 tssh 程序 %s\n", originalTssh)
        os.Exit(1)
    }

    // 备份现有配置
    if _, err := os.Stat(configFile); err == nil {
        os.Rename(configFile, backupFile)
    }

    // 设置清理函数
    defer func() {
        os.Remove(configFile)
        if _, err := os.Stat(backupFile); err == nil {
            os.Rename(backupFile, configFile)
        }
    }()

    // 解密配置文件
    cmd := exec.Command("gpg", "--quiet", "--batch", "--decrypt", gpgFile)
    output, err := cmd.Output()
    if err != nil {
        fmt.Fprintf(os.Stderr, "解密失败: %v\n", err)
        os.Exit(1)
    }

    // 写入临时配置
    err = ioutil.WriteFile(configFile, output, 0600)
    if err != nil {
        fmt.Fprintf(os.Stderr, "写入配置失败: %v\n", err)
        os.Exit(1)
    }

    // 启动 goroutine 监控配置文件删除
    go func() {
        // 等待 tssh 读取配置并显示主机列表（通常需要 2-3 秒）
        time.Sleep(3 * time.Second)
        
        // 立即删除解密的配置文件
        if _, err := os.Stat(configFile); err == nil {
            os.Remove(configFile)
        }
    }()

    // 执行原始 tssh
    cmd = exec.Command(originalTssh, os.Args[1:]...)
    cmd.Stdout = os.Stdout
    cmd.Stderr = os.Stderr
    cmd.Stdin = os.Stdin
    
    if err := cmd.Run(); err != nil {
        if exitError, ok := err.(*exec.ExitError); ok {
            os.Exit(exitError.Sys().(syscall.WaitStatus).ExitStatus())
        }
        os.Exit(1)
    }
}
'@
    
    # 6. 检查 Go 编译器
    if (!(Get-Command go -ErrorAction SilentlyContinue)) {
        Write-ColorOutput "正在安装 Go..." "Yellow"
        scoop install go
    }
    
    # 编译包装程序
    $goFile = "$tsshRealPath\tssh-wrapper.go"
    $goCode | Out-File -FilePath $goFile -Encoding UTF8
    
    Push-Location $tsshRealPath
    try {
        $env:GOOS = "windows"
        $env:GOARCH = "amd64"
        go build -o tssh-new.exe tssh-wrapper.go
        
        if ($LASTEXITCODE -eq 0) {
            # 替换原始程序
            Remove-Item $originalExe -Force
            Move-Item "tssh-new.exe" $originalExe -Force
            Remove-Item $goFile -Force
            
            Write-ColorOutput "编译包装程序成功" "Green"
        } else {
            Write-ColorOutput "编译失败" "Red"
            exit 1
        }
    } finally {
        Pop-Location
    }
    
    # 7. 配置 GPG 代理
    $gpgAgentConf = "$env:APPDATA\gnupg\gpg-agent.conf"
    $gpgDir = Split-Path $gpgAgentConf
    
    if (!(Test-Path $gpgDir)) {
        New-Item -ItemType Directory -Path $gpgDir -Force
    }
    
    $agentConfig = @"
default-cache-ttl 28800
max-cache-ttl 86400
"@
    
    $agentConfig | Out-File -FilePath $gpgAgentConf -Encoding UTF8 -Force
    
    # 重启 GPG 代理
    gpg-connect-agent killagent /bye 2>$null
    Start-Sleep 2
    gpg-connect-agent /bye 2>$null
    
    Write-ColorOutput "`n安装完成！" "Green"
    Write-ColorOutput "现在可以直接使用 'tssh' 命令，系统会自动解密配置文件" "Green"
    Write-ColorOutput "首次使用时需要输入 GPG 密码，之后会自动缓存" "Blue"
    
    return
}

# 默认显示帮助
Write-ColorOutput "使用方法:" "Yellow"
Write-ColorOutput "  -Reset    重置到原始状态" "White"
Write-ColorOutput "  -Install  安装增强安装器" "White"
Write-ColorOutput "" "White"
Write-ColorOutput "示例:" "Yellow"
Write-ColorOutput "  .\setup-tssh-encryption.ps1 -Reset     # 重置" "White"
Write-ColorOutput "  .\setup-tssh-encryption.ps1 -Install   # 安装" "White"