#!/system/bin/sh
# powercfg template by yc9559 & cjybyjk
# License: GPL V3

project_name="template"
prj_ver="(prj_ver)"
project_author="yc9559 & cjybyjk"
generate_date=""
soc_name="template"

project_info="$project_name
Version: $prj_ver
Author: $project_author
Platform: $soc_name
Generated at $generate_date"

CUR_LEVEL_FILE="/dev/perf_cur_level"
PARAM_BAK_FILE="/dev/perf_param_bak"

# const variables
PARAM_NUM=0

# global dirs
[GLOBAL_DIRS]

# sysfs_obj
[sysfs_obj]

# levels
[levels]

# global variables
NOT_MATCH_NUM=0

# $1:value $2:file path
lock_value() 
{
    if [ -f ${2} ]; then
        chmod 0666 ${2}

        echo ${1} > ${2}
        chmod 0444 ${2}
    fi
}

# $1:level_number
check_level()
{
    eval tmp="$"level${1}_val${PARAM_NUM}
    if [ -z "$tmp" ]; then
        echo "level $1 not included."
        exit 1
    fi
}

# $1:level_number
apply_level() 
{
    check_level $1
    # 1. backup
    backup_default
    # 2. apply modification
    for n in `seq ${PARAM_NUM}`
    do
        eval obj="$"sysfs_obj${n}
        eval val="$"level${1}_val${n}
        lock_value "${val}" ${obj}
    done
    # 3. save current level to file
    echo ${1} > ${CUR_LEVEL_FILE}
}

# $1:value $2:file path
check_value() 
{
    if [ -f ${2} ]; then
        expected="${1}"
        actual="`cat ${2}`"
        if [ "${actual}" != "${expected}" ]; then
            # input_boost_freq has a additional line break
            case1=$(echo "${actual}" | grep "${expected}")
            # Actual scaling_min_freq is 633600, but given is 633000. That's OK
            case2=$(echo "${2}" | grep -E "scaling_m.{2}_freq$")
            # skip msm_performance/parameters: cpu_min_freq and cpu_max_freq
            case3=$(echo "${2}" | grep -E "cpu_m.{2}_freq$")
            if [ "${case1}" == "" ] && [ "${case2}" == "" ] && [ "${case3}" == "" ]; then
                NOT_MATCH_NUM=$(expr ${NOT_MATCH_NUM} + 1)
                echo "[FAIL] ${2}"
                echo "expected: ${expected}"
                echo "actual: ${actual}"
            fi
        fi
    else
        echo "[IGNORE] ${2}"
    fi
}

# $1:level_number
verify_level() 
{
    check_level $1
    for n in `seq ${PARAM_NUM}`
    do
        eval obj="$"sysfs_obj${n}
        eval val="$"level${1}_val${n}
        check_value "${val}" ${obj}
    done
    echo "Verified ${PARAM_NUM} parameters, ${NOT_MATCH_NUM} FAIL"
}

backup_default()
{
    if [ ${HAS_BAK} -eq 0 ]; then
        # clear previous backup file
        echo "" > ${PARAM_BAK_FILE}
        for n in `seq ${PARAM_NUM}`
        do
            eval obj="$"sysfs_obj${n}
            echo "bak_obj${n}=${obj}" >> ${PARAM_BAK_FILE}
            echo "bak_val${n}=\"`cat ${obj}`\"" >> ${PARAM_BAK_FILE}
        done
        echo "Backup default parameters has completed."
    else
        echo "Backup file already exists, skip backup."
    fi
}

restore_default()
{
    if [ -f ${PARAM_BAK_FILE} ]; then
        # read backup variables
        while read line
        do
            eval ${line}
        done < ${PARAM_BAK_FILE}
        # set backup variables
        for n in `seq ${PARAM_NUM}`
        do
            eval obj="$"bak_obj${n}
            eval val="$"bak_val${n}
            lock_value "${val}" ${obj}
        done
        echo "Restore OK"
    else
        echo "Backup file for default parameters not found."
        echo "Restore FAIL"
    fi
}

# suppress stderr
(

echo ""

# backup runonce flag
if [ -f ${PARAM_BAK_FILE} ]; then
    HAS_BAK=1
fi

action=$1
# default option is "balance"
[ -z "$action" ] && action="balance"

if [ "$action" = "-h" ]; then
    echo "$project_info"
    echo "
Usage: powercfg [options]
options:
    -h                  Show this message
    -s [mode]           Apply [mode] during boot
    debug               Run parameters verification
    restore             Restore backuped parameters
    level [0-6]         Set performacne level
    powersave           Equals \"level 5\"
    balance             Equals \"level 3\"
    performance         Equals \"level 1\"
    fast                Equals \"level 0\"
"
fi

if [ "$action" = "-s" ]; then
    shift
    $action="$1"
    echo "$*" > /data/perf_mode
fi

if [ "$action" = "debug" ]; then
    echo "$project_info"
    echo ""
    # perform parameter verification
    cur_level=`cat ${CUR_LEVEL_FILE}`
    if [ -n "${cur_level}" ]; then
        echo "Current level: ${cur_level}"
        verify_level ${cur_level}
    else
        echo "Current level: not detected"
    fi
    echo ""
    exit 0
fi

if [ "$action" = "restore" ]; then
    restore_default
fi

if [ "$action" = "powersave" ]; then
    echo "Applying powersave..."
    apply_level 5
    echo "powersave applied."
fi

if [ "$action" = "balance" ]; then
    echo "Applying balance..."
    apply_level 3
    echo "balance applied."
fi

if [ "$action" = "performance" ]; then
    echo "Applying performance..."
    apply_level 1
    echo "performance applied."
fi

if [ "$action" = "fast" ]; then
    echo "Applying fast..."
    apply_level 0
    echo "fast applied."
fi

if [ "$action" = "level" ]; then
    level=${2}
    if [ "${level}" -ge "0" ] && [ "${level}" -le "6" ]; then
        echo "Applying level ${level}..."
        apply_level ${level}
        echo "level ${level} applied."
    else
        echo "Level ${level} not supported."
    fi
fi

echo ""

# suppress stderr
) 2>/dev/null

exit 0
