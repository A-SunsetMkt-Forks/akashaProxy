#!/system/bin/sh

MIN_KSU_VERSION=11563
MIN_KSUD_VERSION=11563
MIN_MAGISK_VERSION=26402

sed_template() {
    local=$(grep -i "^$1=" ${clash_data_dir}/clash.config | awk -F '=' '{print $2}' | sed "s/\"//g")
    template=$(grep -i "^$1=" ${MODPATH}/clash/clash.config | awk -F '=' '{print $2}' | sed "s/\"//g")
    sed -i "s/${template}/${local}/g" ${MODPATH}/clash/clash.config
    echo "已恢复新版配置中的 $1 为 $local"
}

if [ ! $KSU ];then
    ui_print "- Magisk ver: $MAGISK_VER"
    if [[ $($MAGISK_VER | grep "kitsune") ]] || [[ $($MAGISK_VER | grep "delta") ]]; then
        ui_print "*********************************************************"
        ui_print "不支持 Magisk Delta 和 Magisk kitsune"
        echo "">remove
        abort "*********************************************************"
    fi
    
    ui_print "- Magisk version: $MAGISK_VER_CODE"
    if [ "$MAGISK_VER_CODE" -lt MIN_MAGISK_VERSION ]; then
        ui_print "*********************************************************"
        ui_print "! 请使用 Magisk alpha 26301+"
        abort "*********************************************************"
    fi
elif [ $KSU ];then
    ui_print "- KernelSU version: $KSU_KERNEL_VER_CODE (kernel) + $KSU_VER_CODE (ksud)"
    if ! [ "$KSU_KERNEL_VER_CODE" ] || [ "$KSU_KERNEL_VER_CODE" -lt $MIN_KSU_VERSION ] || [ "$KSU_VER_CODE" -lt $MIN_KSUD_VERSION ]; then
        ui_print "*********************************************************"
        ui_print "! KernelSU 版本太旧!"
        ui_print "! 请将 KernelSU 更新到最新版本"
        abort "*********************************************************"
    fi
else
    ui_print "! 未知的模块管理器"
    ui_print "$(set)"
    abort
fi


status=""
architecture=""
system_gid="1000"
system_uid="1000"
clash_data_dir="/data/clash"
modules_dir="/data/adb/modules"
ABI=$(getprop ro.product.cpu.abi)
mkdir -p ${clash_data_dir}/run
mkdir -p ${clash_data_dir}/clashkernel

if [ ! -f ${clash_data_dir}/clashkernel/clashMeta ];then
    unzip -o "$ZIPFILE" 'bin/*' -d "$TMPDIR" >&2
    if [ -f "${MODPATH}/bin/clashMeta-android-${ABI}.tar.bz2" ];then
        tar -xjf ${MODPATH}/bin/clashMeta-android-${ABI}.tar.bz2 -C ${clash_data_dir}/clashkernel/
        mv -f ${clash_data_dir}/clashkernel/clashMeta-android-${ABI} ${clash_data_dir}/clashkernel/clashMeta
    else
        if [ -f "${MODPATH}/bin/clashMeta-android-default.tar.bz2" ];then
            tar -xjf ${MODPATH}/bin/clashMeta-android-${ABI}.tar.bz2 -C ${clash_data_dir}/clashkernel/
            mv -f ${clash_data_dir}/clashkernel/clashMeta-android-${ABI} ${clash_data_dir}/clashkernel/clashMeta
        else
            ui_print "未找到架构: ${ABI}"
            abort "请使用 “make default” 为${ABI}架构编译clashMeta"
        fi
    fi
fi

unzip -o "${ZIPFILE}" -x 'META-INF/*' -d ${MODPATH} >&2
unzip -o "${ZIPFILE}" -x 'clash/*' -d ${MODPATH} >&2

if [ -f "${clash_data_dir}/config.yaml" ];then
    ui_print "- config.yaml 文件已存在 跳过覆盖."
    rm -rf ${MODPATH}/clash/config.yaml
fi

if [ -f "${clash_data_dir}/clash.yaml" ];then
    ui_print "- clash.yaml 文件已存在 跳过覆盖."
    rm -rf ${MODPATH}/clash/clash.yaml
fi

if [ -f "${clash_data_dir}/packages.list" ];then
        ui_print "- packages.list 文件已存在 跳过覆盖."
        rm -rf ${MODPATH}/clash/packages.list
fi

if [ -f "${clash_data_dir}/clash.config" ];then
    str=$(sed -n '/##############自定义设置区##################/,/##############高级设置区(没有需求请勿修改 更新时会覆盖)##################/p' ${MODPATH}/clash/clash.config)
    
    if [ "${str}" != "" ];then
        for name in $(echo "${str}" | grep "=" | awk -F '=' '{print $1}')
        do
            sed_template "${name}"
        done
    else
        # 兼容vfdf3333之前的版本
        sed_template "Split"
        sed_template "udp"
        sed_template "disable_ipv6"
        sed_template "auto_config"
        sed_template "auto_updateSubcript"
        sed_template "auto_updateGeoIP"
        sed_template "auto_updateGeoSite"
        sed_template "auto_updateclashMeta"
        sed_template "restart_update"
        sed_template "alpha"
        sed_template "go120"
        sed_template "cgo"
        sed_template "update_subcriptInterval"
        sed_template "update_geoXInterval"
        sed_template "Clash_port_skipdetection"
        sed_template "WaitClashStartTime"
        sed_template "safe_ui"
        sed_template "mode"
        sed_template "proxyGoogle"
        sed_template "ml"
        sed_template "adguard"
    fi
fi

cp -Rf ${MODPATH}/clash/* ${clash_data_dir}/
rm -rf ${MODPATH}/clash
rm -rf ${MODPATH}/bin
rm -rf ${MODPATH}/clashkernel

ui_print "- 开始设置权限."
set_perm_recursive ${MODPATH} 0 0 0770 0770
set_perm_recursive ${clash_data_dir} ${system_uid} ${system_gid} 0770 0770
set_perm_recursive ${clash_data_dir}/scripts ${system_uid} ${system_gid} 0770 0770
set_perm_recursive ${clash_data_dir}/mosdns ${system_uid} ${system_gid} 0770 0770
set_perm_recursive ${clash_data_dir}/adguard ${system_uid} ${system_gid} 0770 0770
set_perm_recursive ${clash_data_dir}/clashkernel ${system_uid} ${system_gid} 6770 6770
set_perm  ${clash_data_dir}/mosdns/mosdns  ${system_uid}  ${system_gid}  6770
set_perm  ${clash_data_dir}/adguard/AdGuardHome  ${system_uid}  ${system_gid}  6770
set_perm  ${clash_data_dir}/clashkernel/clashMeta  ${system_uid}  ${system_gid}  6770
set_perm  ${clash_data_dir}/clash.config ${system_uid} ${system_gid} 0770
set_perm  ${clash_data_dir}/packages.list ${system_uid} ${system_gid} 0770


ui_print ""
ui_print "教程见→https://github.com/ModuleList/akashaProxy"
ui_print "************************************************"
ui_print "Telegram Channel: https://t.me/akashaProxy"
ui_print ""
