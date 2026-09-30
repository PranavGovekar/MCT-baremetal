set WORKSPACE ./build/vitis_workspace
set XSA_FILE ./build/ct_bd.xsa

file delete -force $WORKSPACE
file mkdir $WORKSPACE
setws $WORKSPACE

platform create -name "ct_platform" -hw $XSA_FILE -no-boot-bsp
domain create -name "standalone_domain" -os standalone -proc psu_cortexa53_0
app create -name "ct_app" -platform "ct_platform" -domain "standalone_domain" -template "Empty Application(C)"

file copy -force ./sw/main.c $WORKSPACE/ct_app/src/main.c

app build -name "ct_app"
