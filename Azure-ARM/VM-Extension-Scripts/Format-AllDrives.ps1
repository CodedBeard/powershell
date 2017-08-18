$i = 0;
(get-disk).where({$_.Number -notin "0","1"}) |% {
    $d = $_;
    if($d.PartitionStyle -ne "RAW"){
        continue;
    }
    Initialize-Disk -Number $($d.Number) -PartitionStyle GPT;
    $dp = New-Partition -DiskNumber $($d.Number) -UseMaximumSize -AssignDriveLetter;
    Format-Volume -DriveLetter $($dp.DriveLetter) -NewFileSystemLabel "Service-Fabric-$i" -FileSystem NTFS;
    $i++
}

exit 0;