$i = 0;
(get-disk).where({$_.OperationalStatus -eq "Offline"}) |% {
    $d = $_;
    Initialize-Disk -Number $($d.Number) -PartitionStyle GPT;
    $dp = New-Partition -DiskNumber $($d.Number) -UseMaximumSize -AssignDriveLetter;
    Format-Volume -DriveLetter $($dp.DriveLetter) -NewFileSystemLabel "Service-Fabric-$i" -FileSystem NTFS;
    $i++
}