# vm-cachyos.nu
# Hardware-Accelerated QEMU/KVM Virtual Machine Management for CachyOS and Hyprland
#
# Provides seamless testing of CachyOS live ISO installations and installed systems
# with VirtIO GPU and OpenGL 3D hardware acceleration (VirGL).

# Create a dynamic qcow2 virtual disk
@category vm
@search-terms qemu kvm disk cachyos
export def "vm-cachyos create-disk" [
    --size: string = "40G",                                  # Disk size (e.g. 40G, 60G)
    --path: string = "/home/kira/temp/cachyos_vm_disk.qcow2"  # Path to destination disk image
] {
    let disk_dir = ($path | path dirname)
    if not ($disk_dir | path exists) {
        mkdir $disk_dir
    }
    
    print $"Creating QEMU qcow2 disk ($path) of size ($size)..."
    ^qemu-img create -f qcow2 $path $size
    print $"✓ Virtual disk created successfully at ($path)"
}

# Boot CachyOS Live ISO with KVM and VirGL 3D hardware acceleration
@category vm
@search-terms qemu kvm boot iso cachyos hyprland
export def "vm-cachyos boot-iso" [
    --iso: string = "/home/kira/temp/cachyos-desktop-linux-260426.iso", # Path to CachyOS installer ISO
    --disk: string = "/home/kira/temp/cachyos_vm_disk.qcow2",          # Target VM disk image
    --ram: string = "8G",                                              # RAM allocation
    --cores: int = 4                                                   # CPU cores
] {
    if not ($iso | path exists) {
        error make { msg: $"CachyOS ISO not found at ($iso)" }
    }

    if not ($disk | path exists) {
        print $"Target disk ($disk) does not exist. Creating automatically..."
        vm-cachyos create-disk --path $disk
    }

    print $"Booting CachyOS Live ISO ($iso) with KVM and VirGL 3D acceleration..."
    print $"Configuration: ($ram) RAM, ($cores) CPU Cores, VirtIO-GPU - GL On"
    
    let args = [
        "-enable-kvm",
        "-m", $ram,
        "-smp", ($cores | into string),
        "-cpu", "host",
        "-drive", $"file=($disk),format=qcow2,if=virtio",
        "-cdrom", $iso,
        "-boot", "d",
        "-vga", "virtio",
        "-display", "sdl,gl=on",
        "-device", "virtio-net-pci,netdev=net0",
        "-netdev", "user,id=net0",
        "-device", "intel-hda",
        "-device", "hda-duplex"
    ]
    ^qemu-system-x86_64 ...$args
}

# Boot installed CachyOS system from disk image with 3D acceleration
@category vm
@search-terms qemu kvm run cachyos hyprland
export def "vm-cachyos run" [
    --disk: string = "/home/kira/temp/cachyos_vm_disk.qcow2", # VM disk image
    --ram: string = "8G",                                     # RAM allocation
    --cores: int = 4                                          # CPU cores
] {
    if not ($disk | path exists) {
        error make { msg: $"VM disk ($disk) not found. Boot ISO first to install CachyOS." }
    }

    print $"Booting CachyOS VM from disk ($disk)..."
    print $"Configuration: ($ram) RAM, ($cores) CPU Cores, VirtIO-GPU (GL On)"

    let args = [
        "-enable-kvm",
        "-m", $ram,
        "-smp", ($cores | into string),
        "-cpu", "host",
        "-drive", $"file=($disk),format=qcow2,if=virtio",
        "-vga", "virtio",
        "-display", "sdl,gl=on",
        "-device", "virtio-net-pci,netdev=net0",
        "-netdev", "user,id=net0",
        "-device", "intel-hda",
        "-device", "hda-duplex"
    ]
    ^qemu-system-x86_64 ...$args
}
