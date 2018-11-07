text/x-shellscript
#!/bin/bash
# --------------------------------------------------------------------------------------------------------------
# We are explicitly not using a templating language to inject the values as to encourage the user to limit their
# set of templating logic in these files. By design all injected values should be able to be set at runtime,
# and the shell script real work. If you need conditional logic, write it in bash or make another shell script.
# --------------------------------------------------------------------------------------------------------------
# uncomment these line to run line by line
# set -x
# trap read debug

LOAD_BALANCER_DNS=k8s.oz.noris.de

LOAD_BALANCER_PORT=6443
POD_SUBNET="10.233.0.0"
POD_SUBNETMASK="16"
BOOTSTRAP_TOKEN="3z9m9i.2vkoev9par1r1vca"
KUBE_VERSION="1.11.4"

LOCAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
sudo apt install -y dnsutils

HOSTS=( "master-1-test2" "master-2-test2" "master-3-test2" )
declare -A HOST_IPS

for h in ${HOSTS[@]}; do HOST_IPS[$h]=$(dig  +short $h); done

CLUSTER=$(for item in ${!HOST_IPS[@]}; do (printf "%s=https://%s:2380," $item ${HOST_IPS[$item]}); done)
# remove that last comma
CLUSTER=${CLUSTER%?}

CA_CRT_ETCD="LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUN3akNDQWFxZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFTTVJBd0RnWURWUVFERXdkbGRHTmsKTFdOaE1CNFhEVEU0TVRFd016QTBOVGswTlZvWERUSTRNVEF6TVRBME5UazBOVm93RWpFUU1BNEdBMVVFQXhNSApaWFJqWkMxallUQ0NBU0l3RFFZSktvWklodmNOQVFFQkJRQURnZ0VQQURDQ0FRb0NnZ0VCQUw4aXlYbWN0ZHdsClU1K2lvTU0vTU4rckxVVEE0cW80UDZJMnN4SHRBN3pYMlludmVNYllCQmhVK3NoSWFTS3NSUmhWc2FGdzFVcHIKS29ybnRaZWNsRDNBWk5kbEpNcmMyaFdYbDhWQ3Nxa2FqVWFUQ0ZoSjhVRTd3MnFTOVJOci9DNkFFVkl2YmdMWQpNY2JmMjVQZi9wM0ZnWnF5SzM3eGlucmNJZy9sZE9lTkQ5NmZuV1lRd3VpRjA3TGQyZmF4NllZbldxSExBUzNhCnJDanM2bnZIc0E4WXpWSGdOZ045T1pGVk1CTzVzeVMvVmVxMDgyTmJLWi8rclJmek5ZYWZPTGFOVUdSalg2SFYKS1hmV2wvekJsSDlVWEJzMlMyNjlDUGxtM0FrdVYvWVZ5NUxsWURkeUNRZ1p1NWxjeVQ2a1A5RnZvU2lKWGwrcgpKNEJWdWkvRXErY0NBd0VBQWFNak1DRXdEZ1lEVlIwUEFRSC9CQVFEQWdLa01BOEdBMVVkRXdFQi93UUZNQU1CCkFmOHdEUVlKS29aSWh2Y05BUUVMQlFBRGdnRUJBRmxmOFZYRGFYYSs2RmIrVHlGeGI0ZjNER1gwc3lGTjhHS08KOFNqL21RNmVXRjJyZnIvenUyUXZFc3ZoU0o3NnJ1eUlxUEtyQ0Y1eWp4M2RUOFYrYTY4a3Q2eEVNVWx6czhQWgpYeWF3eXZMN1ZOZWo1dWxzbzdWMVR3Tm1MdnZkcmtzWHpIVUNNcVpvR0RHYXBucFg1Y3FPS2tMb3JUc21XYUo1CjlXSHRHMVRYRVRQZ0RGZi8vWHJWa0lBVkROMnBhOTkvYVF1d2djVlRYbFBsYUJaYUF0cENBb3QyWWt6akc1VkQKWURlVG9NWko1SmVsd2NSeUV4MDNzWUxEUXgvUVhiS3d5eTdnbTlEV2ZUYnNoVUpLcWhtT1VFUFpLUzZ1cDhtSApPMnMvNUlsdzRqbWtOQTdFNEVsTVdCQ2dhWGVGcjRNVWg4bFB3K3hQclFwQUJuQThVM0U9Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K"
CA_KEY_ETCD="LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFb2dJQkFBS0NBUUVBdnlMSmVaeTEzQ1ZUbjZLZ3d6OHczNnN0Uk1EaXFqZy9vamF6RWUwRHZOZlppZTk0Cnh0Z0VHRlQ2eUVocElxeEZHRld4b1hEVlNtc3FpdWUxbDV5VVBjQmsxMlVreXR6YUZaZVh4VUt5cVJxTlJwTUkKV0VueFFUdkRhcEwxRTJ2OExvQVJVaTl1QXRneHh0L2JrOS8rbmNXQm1ySXJmdkdLZXR3aUQrVjA1NDBQM3ArZApaaERDNklYVHN0M1o5ckhwaGlkYW9jc0JMZHFzS096cWU4ZXdEeGpOVWVBMkEzMDVrVlV3RTdtekpMOVY2clR6Clkxc3BuLzZ0Ri9NMWhwODR0bzFRWkdOZm9kVXBkOWFYL01HVWYxUmNHelpMYnIwSStXYmNDUzVYOWhYTGt1VmcKTjNJSkNCbTdtVnpKUHFRLzBXK2hLSWxlWDZzbmdGVzZMOFNyNXdJREFRQUJBb0lCQUhzWVRVY2NET2RseHJCVgpqVkdSUGNtZXRYM0U5M1dHMmp4L0c5NWNsWDZtU0x5VDFHWERNd2YwbXJvb0lFV3JTcWg4Yi9TMzlUV0RSUmZHCldHWDIrbVcycFhzdThYNFF0QWNaNVMydVlkK1VjUTNWblpjMnI4QkNXLzBqL2Qvdk9LODkzV25maitzWER4KzAKaGZaN1dNQ0ZOWTNLVjBiZkNqOUx6RWdPajdhYlBuc2FaMGg5OGkwK21QZUtHT2s0cmtyZS9KcDZHUUtIK1Bxego0WmhSUHlQNjkwYzgxOUh5Z3IyQ0dZTm56ZlNjcHVldS9wZDNOdE9vVVBZS1BTOGEvM2swTkdobkVHZ0dJMnliCkNBUnNzOVpiVmljTEJpU0tqVU5zUUN5dVFkRFpKMGZSU2tNQnFJK2FVUTNkMW5CcC93Z2YxN1oxaW1KMXdRZ1QKRU1QWjVMRUNnWUVBMmJ1V29sUHBOMkY5TjRPTWJIRlFLRVFtbVBMZGZrYVAydzRCL1BDWEg0OWFsNlljR1lpYwo4QnVlZURSUzF5TFhsWnNOVUE0TG12UlAvRDV2cXlLM2UwSlNwSWNhZUJxZEJJd3dnUTZFcnA1MVJQelhxaUtFCkFMelhZTXdxbVhSOElkMUsyYWVIcGxLQUNVR1ppcStnc0xpL09TQ2t3MVlIZW9xcWRva3JJRDhDZ1lFQTRMcUgKcHpNdzVsbEtTTXd5cExuUnVXQW03MTdvMVA1K0I0eTE0T3VuWm1SWjdIWUZNcmVBMkRheUh0OE1Uc1J0NkUzUwozc0NzczNhN0pyN2tUa1M2YnpwaFA5R1lFSHNhZ0FxdXNVanBFVGNGeGFEZ2FMd25qWlBHNmo4bkwrRUlWaVFvCnhRVnpSdWQ5RTQwTnJyZXNYMzBqVldESS8wTHJiUGluRGs1OENsa0NnWUFCcXZRdWJpSWRNSHY3RHVEbWU3KzMKYno0MGNiZk1uZEhBUmMweUdNMnZpak9SY2M1SlM4aVg5ajR5Z1lRWTdjVmsrZmtTSWVsbzJISThabVlJazQyQQpQalBQMnRFVEZuRVpkZEZ4UzZFc2pUNHN0eHNYeklmaVVZLzh4OU9UdFZhMkU3SGRGUEZ2RHJhNFcyNUhwNnk5CmJjelpMU3pWNmpUSWRZTjB3UHc1bFFLQmdEaVF1dlJxL2pQODVhWE5RRElXVTZQRmdBZGdiRnF3ZENpU1VuVjYKMjNmNmFtZ0tqT1JuTEJkQUxUVjREekVFWUdYSXNQdEFwRGZIK3ZPVnVRRzZhdkwwVHVZeGE0VTZkMEVqYnpWUQpsTm13YjlOKzJ2MkIzckxVTDQxbXVBWmxMaVFBbGdLQmpMS2NNZTlwNGJmSW82cWxaTzlvblM4ak9QOEUxNGZTCldZYUJBb0dBRmJYQm5vR2ZCZGRkTjZJdlZRNXhUcU1naWFLQ2VkMExESHlxajlKN1lWRjY0RG5mMjZRb1Q1RTEKOEMrV0Z0ZVAzbmI3Wml1RVltdy9XcFFxT3FCNm9zalFqQ0pnMnFoOTJudGZVTEpBVkZkMjNvK3pxQlIwdHRJNQpvUzFORjRodXFEZDh4SWJha0lmb28rWTEyUWZkUDY3QWExUGhFMjRheHBJdFFVNmdUdkU9Ci0tLS0tRU5EIFJTQSBQUklWQVRFIEtFWS0tLS0tCg=="

CA_CRT="LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUN5RENDQWJDZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRFNE1URXdNekEwTlRrME4xb1hEVEk0TVRBek1UQTBOVGswTjFvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBTU9BCkNHQU5jUjVRQWV3MlljY2V0eWVyYktiODd4RWRPVlp2aUdneElrbkpKTTZwZFVBbzMwSWVxckRqSnlFaTFVeDcKU0c5NS9sRlBqU1htdHhhNHMvc1g1KzNTVW4zZEtFRWw5TFhXa0lzeTRJYzRFUTMwWE9WcnNuYTYwN1UzNmQyaAp3NHdTK1dveE5QR3dqZDM2bXQzMFR4bUluYk54ZVl5d2NnVU1tMlZFZXM4dGhVaVhZMXB1N1Y2SUNCY243cE9NCkdoT2xlRXg4SmlEVnhuSGlpSm9oYytCbGNIdHdLU1pzK2cvZUhwdGdlSDdaQlZNRC8zZVFvZXVsUGVvTEkwamEKc09jTENMTkpEVVBLUWJqRnRNbkFZSXVvOENHSXpFTzBDaDZNeW5vb1pTL0E0bEs1MXJmTVdkTkZ4N0dVdnQxYQo5KzZzMHo2NEpHeVFBdmtBcWhVQ0F3RUFBYU1qTUNFd0RnWURWUjBQQVFIL0JBUURBZ0trTUE4R0ExVWRFd0VCCi93UUZNQU1CQWY4d0RRWUpLb1pJaHZjTkFRRUxCUUFEZ2dFQkFEbWs1NEYzZ1BqOS91NzlRbTg2V1Mzck5YaFoKZG16Wmt3TXRDajRuTXdsSndGQy9iZUU4ZUdsWnFxWDcrdEpYUDVaY0xLNE1pSnM1U2JTMjd5NDF3WTRRTFFWaQpVWmRocEFHUTBOSlpHSGhWMTVDczlVQTA1ZTFNajNCaHZ6SG5VV2t1ZUhYbW84VmI4SkI5RGloeGdiUW5GY2FQCjRWcVhWY0pBemxVQ0V5aXhreVRGendZTklJbzJHdGtCdlI1YkxCM0doT2RsQURmQzEwdzgvTmQveFFmRnRWdmYKL3lHaktpbW8rT2xERkV5YittcHVKMVdiN3Y3bnJJSzlSSy9WbVhUWENiOWZLQ3BmQ0hMU0hpa0lEWklZK0wxTQpwbWpXYXZFcjFLSlE5UEJIYmdZSHkxK1F0bkpXRDNjNnJrOUtoNU1zMFhTVmpBc2Z1RWdXaG9CYnlVdz0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo="
CA_KEY="LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFcEFJQkFBS0NBUUVBdzRBSVlBMXhIbEFCN0RaaHh4NjNKNnRzcHZ6dkVSMDVWbStJYURFaVNja2t6cWwxClFDamZRaDZxc09NbklTTFZUSHRJYjNuK1VVK05KZWEzRnJpeit4Zm43ZEpTZmQwb1FTWDB0ZGFRaXpMZ2h6Z1IKRGZSYzVXdXlkcnJUdFRmcDNhSERqQkw1YWpFMDhiQ04zZnFhM2ZSUEdZaWRzM0Y1akxCeUJReWJaVVI2enkyRgpTSmRqV203dFhvZ0lGeWZ1azR3YUU2VjRUSHdtSU5YR2NlS0ltaUZ6NEdWd2UzQXBKbXo2RDk0ZW0yQjRmdGtGClV3UC9kNUNoNjZVOTZnc2pTTnF3NXdzSXMwa05ROHBCdU1XMHljQmdpNmp3SVlqTVE3UUtIb3pLZWlobEw4RGkKVXJuV3Q4eFowMFhIc1pTKzNWcjM3cXpUUHJna2JKQUMrUUNxRlFJREFRQUJBb0lCQVFDaEIrN2VIM1JUZ1pkegoxLytHSWxpL0JrYkM3WWlGMGtxT1ZlUkgzbURkNGg2OVUzdk8wMXZDZkx3Z1k1cXhncDJyRjhrOGVZSHZ1OVVKCnFSYWFVcDE5YjkyTVdUZTFrTnM5Zm1Rbys0bW4vc3BPMXZIRlNzalIrSG5Scm1YLzJRUjdtR2tZRWZEN2RYaWsKczhiSFYwc0ZFOTJycklvcGFvaXlTQXhDK0hWdlhSNFRmRGJYMVlRNDJ4QWRRQXZJbkEraHdJaC8yRnBGZEY2cQpDZEFYL09pdVBXWnJHc3krRk9uN1Zmb2pGNlEwRkNIbWQ2cmhNcnZJTWxhR282ZmhRS1M2MkpiZzlxVVZUa0g4CnAwSjhHSTUvUVJRZi9kZ2h5bXE5a2c2dmkrUHE1aWdzNzRMNnFsTmZXVjczSHRQVGIwRm9mNm1tcE5WSHZwbmoKcUREdkdDWUJBb0dCQU5tZzB3MGt4b0wybkRteGdTVVZKckhZcjRHaU1OeGpSQ3BBNnZtRFN1aEpFOUFVRWY5cgpMVHVhdVlOZ3RncExrYUg5MXRCaEI3SkRuSlR6WjQ1S21vVnREejVRUmxvanFSNWhXUUZsNDI5VWlzeVlGNm1XClRlV2U2RURYUG5YWks5OWwvY3dCVVN5S0p4c3kxa0sxVlEvUTJYSzhLWW85cGo5ZCtHOCt3QnJWQW9HQkFPWDQKWjBNMHROU0YyM3Jqek1uVkhXQ0VNUUh5MU52UFdkektwQkE4YUxaSEVNa2VLY1JReHhGU0VwR1Jic2Y5ZXN0cAozajZBYllGd29FS0l5VHNxZ3NCWTN6Y0VuTGtOSU8vbmtWS3JqUVZCMTZ4bDFFRnFGcEFSWnFHZG1xQ3AycTBpCmZneUNrakEzZ1lpUkQ5OHhTbzhGTjNhbjZWU3Z2OGRJa2tOS3EzSkJBb0dBUWQydDRxMTlzMGRtTXdQcEhVc1EKZ2dVZDRUTXdiSk5TbnlNMHVyMmszemEyMjJRbnFsRkt5RjVreFVGdzl4NjEvZnd3bHJLM1BKbS8rMGpMejhIKwprR0ZZbXJoN0FtOEdrVjVQTE9Ba2ZKNXV2OHRNWmhSS2tUT09BWW5qcXBGRytQOEtXRU1SeVZRcXo4Mk1FWGFHClB4b3JwZEVURlhiaEtRNk0wVWFCcDkwQ2dZQjVHbWJHcldyTXYvRGt0akdSMS9pd2F1eWo2Z3pOOUZPT1FlaEQKNUl2LzhVeVZuSnpDRlFlL3gwaWYvOFltNndWUE9XRWY2T0hCMkYyTXJCdk1YSWFlWkM2bituWE52V3dxNmZkTgpZYW5ScXVxNGpxZElDMlgyV0RPRHlFczFjRDBJRDdIeFJKRlhjdU56MTNCVVNOREtvQ1NsQjZlSVFVVHMzUHFwCkZSbFVBUUtCZ1FDR05xR2VqSVVDZHpRWmJDd3YreWNlZXd5bmh3L0VjYVcwcWRZRnptVmZKY3pXYlQwL1loNGEKUG93eEZGSXUxVTdHV1lmMDd2cDVIejE1YUNxdmxORXZvQmVSYjVVK2pIR045Ly80K2hPS1VvSThKOUpYNFQ4ZwpNWUNVcHBUYkZuZzY5TlJnVzB1dEswUlBXQ1ZZaWFwZDVLNUhyV1JHa3ZvWnliSUpKaDBGVVE9PQotLS0tLUVORCBSU0EgUFJJVkFURSBLRVktLS0tLQo="

SA_KEY="LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFb3dJQkFBS0NBUUVBMWFVRUNORzB3Q01xMWlNSFN0eE9od21iU3VqWjNzUDREUmduaDh3RnI4amNuZGloCnB1bVBMQ1N2TEpJZ1FNNmJpVTRURkpiTnhLM21BMEtubEwvdEQzcWNCRng5dVdsRWUya1ljdE1oeC94cHlGUTcKN0o5dDNldGdwbGMzVFhGelVGbDk2clRFNUZDS0w4WFhNOWJncUNqL1JrUnJmeGZQSkFTSkdVWDlvZ05WMjBZWgpoNDBKREtZd3hBbkp3RFFocUlIbGpPcHpSd1BrdHJlQVg3NEZxYVNpU0tNUEQxd0ZjdlRHckZWcHlRRXhPcGQ3ClFrMFVPNUhoZ3RmbktzZU15WmpVbUFZaFZHZ0dCSi9ZaFI3bjdESGhoMTVMNHc0cHZCcnFybHNvS0pxKzljME8KSVNUTzFabU9UMmgrbnpKdFA5WWEwQ2t6OHFUTDZ0MmRGdGY5VHdJREFRQUJBb0lCQVFDRVc5bG1CVld2KzVtYwpWTk05dzhNNjBlN050L2pTbENKbkttSEROZGtJRUs3dGM3cWloK3hWY3R5OEJrUEpJcmNsbDZNbWpFOHEzSG0xCjUyT2ZPbENKMkhJMEdZRWlqMThIL2hKUmdSQmFyN3h4aWc0ZUNKK3VieGJQdHhUaCs3bHZQQ0pRZUhISzZVTFQKV2dSN2IxSjdtL3FhOCtTTk5wajBQWU1hajB3VlJFMUl6c29aUW4wbno2Zk81YlQxY29aMEhmYmMvbmFFdTMxYgprTlJPQURUZTdtemxwMXNqM2g1YVNmdjc0SlVxa2JQcStYOEdEU0N3cWJGOGFkM091dnp6dTdyd2p6YjJwQ0FrClNObkIxQWR1QUhneFJ5ZUJHSzRMSm83YXlud3NNQWQ3bUVRd2FqNkxyN20vYUtocTk5WHAxemQxcmpmMWRtUUkKY2UzVlZWd2hBb0dCQU5xRHEzVGpzRUZyaS9LSzYxUm5xQjFXQ3V2YXE0RkliUDJJckMvV3JlWHlpTklKTlhVYgo4bitoekIwWkp1ZDJ1VnFmMDdJUUZJc3h3eStKcHVKSHd5VGtRL1VOV2VET3RPYkx3Vm9Yd25PZlV2bWJFMmEzCnZRUHRYNjN1NUV0bk4zUU5SUmE1ZlY0Z0h6c1hBMjR6cEQ3RGRmT2MvZGlCTDZJcFUyU1Vjd3hIQW9HQkFQcEwKZkRWK1N2cFZSYXpQck9kL3Q2L0tzMVdVdEZNQ2pJeXJjR0xrQVRBWjg3T1NWclYxWnluSS9Ed2h1VmRKd0NsegpDOXB6Smw4Mko3VzBraDNKeDNaeGh4SDdFUllhTjBqaU93MTE2WWVMRTlyaXVidnJhM3UxbTZsSnc4UVY2YkhDCmRtT2ZHVFFlQThyb3lLK1o2K3VkckF1NnF3enZHb2xpK2VVaW4vSzVBb0dBUEF5WEg2WTZsNS9RYzdUTmV3S0oKWnBad3BlUVA0WlZmcmtUUzNNcW9PMXJ0VXBzSlA4ZVFXcGJDR3ZVQWhmZFFkS0ViY2dHTlE3dEhJbGMzcjFOOQpRelFmb01Zc2Z1VVBQYVdjMnY5UWhxbXdDYndlRnNwRGZVTE1XbVllQXNLNHNJRzlETU9vdWljbHJmMWpDZlBUCkhSUmw0NjZ1NjhLRXJwR2d3ekV3ZEowQ2dZQWo3akltZTdySHRQWUxtTVI1ZHh3bllESGVWenFMc0JIOUg1OUMKa3ZpWXJ5RU01alVNVjQ0M3NXS0VQMU1iOUxwaE9PSzZ1VTBJM2YxVldGYWhjQlh5S3RuNCt0RzVHb3BWTENUTwpDZDg4VmZyRHNVaDRjWk04YnhXcGQ2MWl1TUtUZ2hiOHRob29JU2JxT2dDVk5NTnBUM2tqTmVqWU1ucmN2aGloCmpCYnFBUUtCZ0QxOWtUckNzL2Y3Z2VRL0xuSzJ1RjJSa2M4Nk1ibExhSDBiT0RPYUE3T0Q0bXZPcDVldWxtN0kKZmlHRHdzWXhEUTFVa0NrclRQM0MwRUphdVR2aVZHN2tyL0V5OWRTNm9Ic0poYmJIUFNSY3JCNFNEclNkY2FCawoyeVRwK2gwWlVCdzg4OEhFRHZCNDJ3YzNZWVdSUGJoUTZaZWlVZW8rQTgwQ0RMWlNndytICi0tLS0tRU5EIFJTQSBQUklWQVRFIEtFWS0tLS0tCg=="
SA_PUB="LS0tLS1CRUdJTiBQVUJMSUMgS0VZLS0tLS0KTUlJQklqQU5CZ2txaGtpRzl3MEJBUUVGQUFPQ0FROEFNSUlCQ2dLQ0FRRUExYVVFQ05HMHdDTXExaU1IU3R4Twpod21iU3VqWjNzUDREUmduaDh3RnI4amNuZGlocHVtUExDU3ZMSklnUU02YmlVNFRGSmJOeEszbUEwS25sTC90CkQzcWNCRng5dVdsRWUya1ljdE1oeC94cHlGUTc3Sjl0M2V0Z3BsYzNUWEZ6VUZsOTZyVEU1RkNLTDhYWE05YmcKcUNqL1JrUnJmeGZQSkFTSkdVWDlvZ05WMjBZWmg0MEpES1l3eEFuSndEUWhxSUhsak9welJ3UGt0cmVBWDc0RgpxYVNpU0tNUEQxd0ZjdlRHckZWcHlRRXhPcGQ3UWswVU81SGhndGZuS3NlTXlaalVtQVloVkdnR0JKL1loUjduCjdESGhoMTVMNHc0cHZCcnFybHNvS0pxKzljME9JU1RPMVptT1QyaCtuekp0UDlZYTBDa3o4cVRMNnQyZEZ0ZjkKVHdJREFRQUIKLS0tLS1FTkQgUFVCTElDIEtFWS0tLS0tCg=="


FRONT_PROXY_CA_CRT="LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUMwRENDQWJpZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFaTVJjd0ZRWURWUVFERXc1bWNtOXUKZEMxd2NtOTRlUzFqWVRBZUZ3MHhPREV4TURNd05EVTVORGhhRncweU9ERXdNekV3TkRVNU5EaGFNQmt4RnpBVgpCZ05WQkFNVERtWnliMjUwTFhCeWIzaDVMV05oTUlJQklqQU5CZ2txaGtpRzl3MEJBUUVGQUFPQ0FROEFNSUlCCkNnS0NBUUVBMFJxVzY5TTlrUEpjdVpOL0l3ZVM1K1FqL1EvNHY0MlYzR0FSZDlRZ1lRb2xValNPOU5qUVZWN2UKNHMrTVhxUnJiNVcvVFZpeU0yelltVFRieWZkZzN6SDBjRUlKUkh5UmVYWWRaUW1JYjRRMUNqL0tqL0Q0WlFobQpXNjFPazVXNzhLVE1WdFZOV1NMYXBYK2tWNkl2OTBzR2loTDVNQi8vbzNpMUx3VlFLYWRqS21RRUpKSnNIV014CnBmRkhMaitaUlJoc0NMVFNWQ3ZtUjA1dWV2R2JXZ2pNTmUyc3NaL24zVWRmY2w4OWh6UFN5YUJEbno2YlJlN00KZkNNRUtjYkE4N1VtT1VLcDRHaXpvKzI1YTVxcVh6NFhUeGZmT2N2RGlvTjFGSExkYWlwOXdUM1N5bVFza1NOcwpHSmVBLy9Hd3J3eWJGU2xBbWpMM2l1N3J4cDExcXdJREFRQUJveU13SVRBT0JnTlZIUThCQWY4RUJBTUNBcVF3CkR3WURWUjBUQVFIL0JBVXdBd0VCL3pBTkJna3Foa2lHOXcwQkFRc0ZBQU9DQVFFQXc5M0ZTclUwYWxMcVIwTVoKNXVSN0k0bUczK1g1NVI4WStVRkJzQVpsNzZlSGplTHEvbStoaWhmdlVYRnFySTNZSmp1Tjczbmo4WG9taWpMRAo3TlAxRU9lZ20velIvTktaYWx2d2FueGdxRFpzVldnUEdraDZyYVNpTEdzR2hCdzVaaDN4N1ZXc0pHRndOc0NJClBoTDlWV0JSZ2FIaEF3TUdra3RDWXFPL2JHcC94MmNBMEZGN1hhV2dmUXBYRCs4WUJSa2t0eWZYUkdHVXhFaGsKMkZHZk1QS1RZVUY4cmQwdVdLdU5sOUJTWHVFSW5NMzRWSlowM2VrVmc4NUZRWHFXZnRCb1VuRlhnSXVZcWp1RwpaeXdDRFhNMyt4SFlQSEZEMWFmTmVLRnFFUEJZYW1CaXAyYksyckhaRG1zRk1DL1Q0ZmJJTktqYXJvWnN2bmVICjJ2UlpvQT09Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K"
FRONT_PROXY_CA_KEY="LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFcFFJQkFBS0NBUUVBMFJxVzY5TTlrUEpjdVpOL0l3ZVM1K1FqL1EvNHY0MlYzR0FSZDlRZ1lRb2xValNPCjlOalFWVjdlNHMrTVhxUnJiNVcvVFZpeU0yelltVFRieWZkZzN6SDBjRUlKUkh5UmVYWWRaUW1JYjRRMUNqL0sKai9ENFpRaG1XNjFPazVXNzhLVE1WdFZOV1NMYXBYK2tWNkl2OTBzR2loTDVNQi8vbzNpMUx3VlFLYWRqS21RRQpKSkpzSFdNeHBmRkhMaitaUlJoc0NMVFNWQ3ZtUjA1dWV2R2JXZ2pNTmUyc3NaL24zVWRmY2w4OWh6UFN5YUJECm56NmJSZTdNZkNNRUtjYkE4N1VtT1VLcDRHaXpvKzI1YTVxcVh6NFhUeGZmT2N2RGlvTjFGSExkYWlwOXdUM1MKeW1Rc2tTTnNHSmVBLy9Hd3J3eWJGU2xBbWpMM2l1N3J4cDExcXdJREFRQUJBb0lCQVFDU21YeXo2MDZmbjN1bwowNkx2OFRCcWlZVTl0NFBpOENYZjhpNXMvM2lQOENnSVFUYjByRWtyZ1M3c2Z5eGZjaENzazZVaVdndmRoL00zClBsclZkeTBnYmdwODVaOVB0N0hhSVJnc3JRbE5mYmdkN21sYWowdm1zWVBweEZCeG9pbTRaaUdvd3pUT1NHUlkKWVd2YjBLYW1UcUJRRDB0TEZUUUo3T2ZDQm95VUZqVFBFRjBRaGU2ZjVyMHJkODhldXZXRmVIS1JWNEgvdDdtZAptVkIyNlkyR3BZOUhnTmxKb2JNV3NLZjRhdnBjZzFucE9XckE0WC9yL0xwV2RRTkxmOGx6ek9JdDJaQTRDbCtqCmhZekI0Lyt3a3E3WDQxREFxYmx2c2pKNnRQV1pjSFR0aE9kVlZtZjI3b3lDSnlSSE5VVzlmbUxiN1c4VVF2UC8KZzYrVUpxL3hBb0dCQVBQVkRUWVlpRG1JQ1ZIbVhkMGgxL0dhSk1aRkJsOCtHZ1cyNldiaU55cUhSaENjU1F1bApYRFV6TTRndTl6OTFwNE5ja1NoOE5XcXowMWtzRlFFVitSQmw0Wjd4amp5Y1Arc3JicEFGWUlDRVV1UHVCTW9MCk5HYTBEUmpiWTNsaUY2aXM5cUlkQk5lbVM0WFR4T1JHWVM1QjRKZ1VrMW04SE8wNjBSZHlDSTR6QW9HQkFOdUoKNGx6TjNFSTFDeFhKVjlFV1dZNnJ5RGRsb2IwZThRQ3dOQmxsanVzUVdzbnNxOEExRisyK2E4VE4xdUxQTW5MVApNa2tTeHNWMjViWFBKYnRiUEtweHVKaGk4aXB1WEhUTDR1aS95WHdzUXpnVzhXcFQ3MjdXWFRWNmIyMW1tM0pqCmthbFYwNk5RWU1VVitRYTN2VSt4UXg3MEZNZHpaUWNtdHllZktCS3BBb0dBVlFkbzBnS0FEci8zc0EzTGtiK3AKbEdFU2plbW9MVEowMUtWU2cwUkR4SnJqdmdzaUZlT1dZaDcyeTNqRlUrWHRnb3VYT3kwRlc2NVY5M1M5NW1FSgpOOFN2aDBQcFBBMm81Sk9Ddk1xRE9vM3FjZjJnd2V4aVc2WlNJdWJ1cTNlZmxIeXNqUi9kZm01SlMrUHJkMGRyCndEdk0zSHZnWHB5UTRkRnU5T1FaUTYwQ2dZRUFnZmxRR3NHRjlXeVI4NFFRaWFsQnZFWFhjM1NvSE4rRXIzT2kKWktiTHhqOFlnUk90VzA0VHJKMWdFRlFOTkpxV3M0UjE4TzA4NFF0VFZDQWZwcHlOZmh0MXZrSldQT2k1dEN4QgpXcXF4RHVMbHFQOXNUaGNEV2d0dmc0bkpEbXdBKytnWEJMbmJZb1RqeGNzTWMvMjBCc3BiZ3FmZTVYWmNDYS9TCkg1TUtsb0VDZ1lFQTc4WWxXOEE4UWp3OTU4bEFpMVNRZHdEYS83WFBQanp1ZXhWNWR4SmkvYVIrL29BM3c0bjMKTEVwTTU1L2FTVm5vbW5ncVVHVjIrcndSYmFUbmdraWlkc1hrYWd5Z2pPazEwdk5rdWNUeXlpK01wWXVHcFBLSgpPRFhtdjhjc0NKS0NzaUdHMVkyS29NTlF2TWUrVUMwcXNsSldTQ1hTQkh3a1dTREJYcENaaXdJPQotLS0tLUVORCBSU0EgUFJJVkFURSBLRVktLS0tLQo="


sudo apt-get update
sudo apt-get install -y software-properties-common
sudo swapoff -a
sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt-add-repository -u "deb http://apt.kubernetes.io kubernetes-xenial main"
sudo apt install -y --allow-downgrades kubeadm=${KUBE_VERSION}-00 kubelet=${KUBE_VERSION}-00 kubectl=${KUBE_VERSION}-00

sudo "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -"
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get -y install docker-ce

sudo mkdir -p /etc/kubernetes/pki/etcd

cat << EOF > /etc/kubernetes/admin.conf
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUN5RENDQWJDZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRFNE1URXdNekEwTlRrME4xb1hEVEk0TVRBek1UQTBOVGswTjFvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBTU9BCkNHQU5jUjVRQWV3MlljY2V0eWVyYktiODd4RWRPVlp2aUdneElrbkpKTTZwZFVBbzMwSWVxckRqSnlFaTFVeDcKU0c5NS9sRlBqU1htdHhhNHMvc1g1KzNTVW4zZEtFRWw5TFhXa0lzeTRJYzRFUTMwWE9WcnNuYTYwN1UzNmQyaAp3NHdTK1dveE5QR3dqZDM2bXQzMFR4bUluYk54ZVl5d2NnVU1tMlZFZXM4dGhVaVhZMXB1N1Y2SUNCY243cE9NCkdoT2xlRXg4SmlEVnhuSGlpSm9oYytCbGNIdHdLU1pzK2cvZUhwdGdlSDdaQlZNRC8zZVFvZXVsUGVvTEkwamEKc09jTENMTkpEVVBLUWJqRnRNbkFZSXVvOENHSXpFTzBDaDZNeW5vb1pTL0E0bEs1MXJmTVdkTkZ4N0dVdnQxYQo5KzZzMHo2NEpHeVFBdmtBcWhVQ0F3RUFBYU1qTUNFd0RnWURWUjBQQVFIL0JBUURBZ0trTUE4R0ExVWRFd0VCCi93UUZNQU1CQWY4d0RRWUpLb1pJaHZjTkFRRUxCUUFEZ2dFQkFEbWs1NEYzZ1BqOS91NzlRbTg2V1Mzck5YaFoKZG16Wmt3TXRDajRuTXdsSndGQy9iZUU4ZUdsWnFxWDcrdEpYUDVaY0xLNE1pSnM1U2JTMjd5NDF3WTRRTFFWaQpVWmRocEFHUTBOSlpHSGhWMTVDczlVQTA1ZTFNajNCaHZ6SG5VV2t1ZUhYbW84VmI4SkI5RGloeGdiUW5GY2FQCjRWcVhWY0pBemxVQ0V5aXhreVRGendZTklJbzJHdGtCdlI1YkxCM0doT2RsQURmQzEwdzgvTmQveFFmRnRWdmYKL3lHaktpbW8rT2xERkV5YittcHVKMVdiN3Y3bnJJSzlSSy9WbVhUWENiOWZLQ3BmQ0hMU0hpa0lEWklZK0wxTQpwbWpXYXZFcjFLSlE5UEJIYmdZSHkxK1F0bkpXRDNjNnJrOUtoNU1zMFhTVmpBc2Z1RWdXaG9CYnlVdz0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
    server: https://${LOAD_BALANCER_DNS}:${LOAD_BALANCER_PORT}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubernetes-admin
  name: kubernetes-admin@kubernetes
current-context: kubernetes-admin@kubernetes
kind: Config
preferences: {}
users:
- name: kubernetes-admin
  user:
    client-certificate-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUM4akNDQWRxZ0F3SUJBZ0lJR280Sm43RnA0V3N3RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB4T0RFeE1ETXdORFU1TkRkYUZ3MHhPVEV4TURZd05URTVNekZhTURReApGekFWQmdOVkJBb1REbk41YzNSbGJUcHRZWE4wWlhKek1Sa3dGd1lEVlFRREV4QnJkV0psY201bGRHVnpMV0ZrCmJXbHVNSUlCSWpBTkJna3Foa2lHOXcwQkFRRUZBQU9DQVE4QU1JSUJDZ0tDQVFFQXVpaGFKb2VESjROSGxDOEsKeC9PUHlEbm9EQ3RBTEIyQTdGbkRTZE1uUGFRQmZmZnZteDIxK000MEw0UjVmeTVUZ0EzdGJFcTZSWU5jOWY2TwpVSzEyanJWWnd1b29jaTZWRmVKenMxOUdKZlhtcTVJSmVzMkI1Z000UE50NDlubExWOFMrd0Y4Mk93NkV4TXllCjVHL1hPNDM1bk8zZG1KZ2JVb1kybHB4ZFQ1OVdRa0xZQ0FSWDJIYjFWM0VDZ2dybmY3MXZUNUxhdEtKeVY0aFkKdWp5Mld5eW94eVhLSXN5NVdqVWFNemRERUtlY25xTjI1NXoxZ0NUcGhoeU5mTVRIakRUVENXbzdsNWNpZWdmLwpqUTJ0d3N6emJNMjd5Y3l0aEhyYjhlMVFlUzk4bENLZGNsWDcya0NkQ3ZNcWt0WWwwZVNiclRPNThWNWxtTlRlCksvWlQyUUlEQVFBQm95Y3dKVEFPQmdOVkhROEJBZjhFQkFNQ0JhQXdFd1lEVlIwbEJBd3dDZ1lJS3dZQkJRVUgKQXdJd0RRWUpLb1pJaHZjTkFRRUxCUUFEZ2dFQkFHMXAyR0ZDcnFKN0hpRWJ6ZmRwQzBSRFZwYzIyK3B1NVNQQgpIQ25EOUU1a1pPVjNrMExnSEhjNVU5UUsvdHhDakVYRmtBZFZMSDd5cmtnVit6djByUUMyUFBlb053aVhHV2lKCmxDbFRORFAzK3FueGxQUVJOTkM3ZkJHbGtPTHNRVFF3LzJKaVBaWEJ1VUozcXVwUXVZd2NSRGV4anZITk5WMEoKb1BNcTJwWG4rUy8wNGNoS2tvbzVNZUhGa2IwQ0Q4QzZZWFZLNGg4SVF3VkF3L0JaQ1BYR0RQVWJnRW5DTE5kawo3dURVQUtmWUFOWFVpSnBEMWJLT0xwclpDclRtclV5bjljQldwbDVNL05MUjF5allCRFlhVlMxTlB5bDk0MjIxCnZMck1PUGtsZW85NmIvOXF1K1dpZEFiMjd3VERMZVh4ZW8vM0drR3AzMUpyQUJ1MFF4Yz0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
    client-key-data: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFb3dJQkFBS0NBUUVBdWloYUpvZURKNE5IbEM4S3gvT1B5RG5vREN0QUxCMkE3Rm5EU2RNblBhUUJmZmZ2Cm14MjErTTQwTDRSNWZ5NVRnQTN0YkVxNlJZTmM5ZjZPVUsxMmpyVlp3dW9vY2k2VkZlSnpzMTlHSmZYbXE1SUoKZXMyQjVnTTRQTnQ0OW5sTFY4Uyt3RjgyT3c2RXhNeWU1Ry9YTzQzNW5PM2RtSmdiVW9ZMmxweGRUNTlXUWtMWQpDQVJYMkhiMVYzRUNnZ3JuZjcxdlQ1TGF0S0p5VjRoWXVqeTJXeXlveHlYS0lzeTVXalVhTXpkREVLZWNucU4yCjU1ejFnQ1RwaGh5TmZNVEhqRFRUQ1dvN2w1Y2llZ2YvalEydHdzenpiTTI3eWN5dGhIcmI4ZTFRZVM5OGxDS2QKY2xYNzJrQ2RDdk1xa3RZbDBlU2JyVE81OFY1bG1OVGVLL1pUMlFJREFRQUJBb0lCQUhTQ050SHdkRFJ4cElYbwozMDEvY1ppMkxUWVloNlJVbnRETjZUeTJLOVFYWmx1cHBrdWx6N00xazFHK0RyQjdsUVVMTW5KWlhyV00zc3lUCkVnMEtVNjVEY0RkZWlBdldmYlpoc1ZvdEllRTJRclZVeEJ3WXJOa0JZTnd0M0VvZVpmbzdoOHNzaSt0d1RjWkIKN3B3NEp6UDl5cURkK3BlN2N6WTJDOG85ZU9VUVdoQ01OaGNQK1JmaHBMb0RQRG9UVTZ0ZnIxUE9XQjlIcWs0Rwp4MTcybUZYMUtJeHhnZDdvaUVHTFZqSytZRnFzYWMvWlVaWE5kV0xKNTFWYW1GeFhkbDNYblA4TnFUYmpjYno3CjUrV1dzMlIvaUdwWExOdmM0YlQ1T2c0ZlA2SUt5Mzh2Q0Z6bVBNbnA0SHo3d2U0cEwwdTJrRUVza1BkYmVjRjIKemZtMXNCVUNnWUVBMnhNUURyOThqVUc0eWdDNDBZVjlZZEhZUCt6LytobmlncG5KdE9wcjRvU2laYk82N3Y0agpwTUdEV1hJWldlM2ZtOFdBcU5oaDBoUGRRRzFxWk9EZVhzemUvNlU5SkxMU0pDMUY1L0wxVUhQc0Q4cjdreWIyClpwVzNrSzg1SmtrWjZ5VC9FMkQwMXkyNUxKbXVYRGVJNUJVQW5sK01ZWnYwaFlLZndzWndya2NDZ1lFQTJZankKWHpYaGlNVFMrVnF0UGhxVkkxL0xwQ25KTzhGSFdjT3F5OWhkMWV6cGdGWTY5dWJvQ1JzUXdvVW93RkUrT1NmYgpXZ1V0RFBDeG4vT0t0WVVBY3lNbGdCRExWN0FCNzVZZFZCYjBodWU5d0VuUWtPSndDTmhRTXA0ZjZQN1lCbjhSCjBSdGhhM2wyOTBTcEdzTnBsVkRoRi95UlVZNVpyMFlYODNyclhOOENnWUJKcDRVVWtFaTk3VVRGbGF5TnRRWE0KcDVLL0cxMk1wcnRERVpXQlgvZFp0eUlxYzF6OEVUSEdxTkVTZDR3U2NpbGw0K2MzM1ZnMkd6dWQ5NnQzc3lyUQpVSzBBNG50R0pXRUZqTHNlR3M5amR6WDhzVkFYejFlMGNjMi90VW5QbDNCQllMVHB2UVZVZXlqdzE5S0phcHA1CnBKNEtvVEUvZUFHa0NhRFJDWXJFN1FLQmdGY1BwUmtQNG15dmdWUkV3ek1veG1sNjdIQ09QTGlLbVRqR3c3T0QKcThKelo5eHlKblVzWXM5S0lzSUhNeEVOTXQ4RElabjhtbFFrZktKc2dTWTJ6Y0JHMzdwS2ZtZGd6TldMZWI5dQoxSHl0Z05iVmRBQ1liNGhLc29ZZm5Odk9LcjBtM0FXWmRMcmp5UVliVjZhYmNNVk9zbGU4UUppb1pTSnQ1aVlQCkd1VjNBb0dCQUxHYW5iQU1yeUZ4b0JTQlhRNDVONjN1Q0NiWm1DUldLZ0JoUStZQnlUdXZmVktRRDJTY2kyM0kKcTFrdnUrTUplYjFSUFRFYUEzMTRoMTM1aFBGdTJMWmF5bmdXalBnN2hHbVBCL0NVMEZrRHY4TTNqL0ZQUm9wQwozM1RBR053RzNRS0R4VWZZTHVrV25JdlJXWEY3cG9xUTgxZDFMNlZFYklqMkpmSmk4ZHU0Ci0tLS0tRU5EIFJTQSBQUklWQVRFIEtFWS0tLS0tCg==
EOF

cat << EOF > /etc/kubernetes/kubeadm-master.yaml
apiVersion: kubeadm.k8s.io/v1alpha2
kind: MasterConfiguration
kubernetesVersion: v${KUBE_VERSION}
apiServerCertSANs:
- "k8s.oz.noris.de"
api:
    controlPlaneEndpoint: "k8s.oz.noris.de:6443"
etcd:
  local:
    image: quay.io/coreos/etcd:v3.3.10
    extraArgs:
      listen-client-urls: "https://127.0.0.1:2379,https://$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4):2379"
      advertise-client-urls: "https://$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4):2379"
      listen-peer-urls: "https://$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4):2380"
      initial-advertise-peer-urls: "https://$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4):2380"
      initial-cluster-state: "new"
      initial-cluster-token: "kubernetes-cluster"
      initial-cluster: ${CLUSTER}
      name: $(hostname -s)
  localEtcd:
    serverCertSANs:
      - "$(hostname -s)"
      - "$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
    peerCertSANs:
      - "$(hostname -s)"
      - "$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
networking:
    podSubnet: "${POD_SUBNET}/${POD_SUBNETMASK}"
    # This CIDR is a Calico default. Substitute or remove for your CNI provider.
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: foobar.fedcba9876543210
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
EOF

echo ${CA_KEY_ETCD} | base64 -d > /etc/kubernetes/pki/etcd/ca.key
echo ${CA_CRT_ETCD} | base64 -d > /etc/kubernetes/pki/etcd/ca.crt
echo ${SA_KEY} | base64 -d > /etc/kubernetes/pki/etcd/sa.key
echo ${SA_PUB} | base64 -d > /etc/kubernetes/pki/etcd/sa.pub
echo ${CA_CRT} | base64 -d > /etc/kubernetes/pki/ca.crt
echo ${CA_KEY} | base64 -d > /etc/kubernetes/pki/ca.key
echo ${FRONT_PROXY_CA_CRT} | base64 -d > /etc/kubernetes/pki/front-proxy-ca.crt
echo ${FRONT_PROXY_CA_KEY} | base64 -d > /etc/kubernetes/pki/front-proxy-ca.key


#sudo kubeadm -v=8 alpha phase certs all --config  kubeadm-master.yaml
#sudo kubeadm -v=8 alpha phase kubelet config write-to-disk --config  kubeadm-master.yaml
#sudo kubeadm -v=6 alpha phase kubelet write-env-file --config  kubeadm-master.yaml
#sudo kubeadm -v=6 alpha phase kubelet config upload  --config kubeadm-master.yaml
#sudo kubeadm -v=8 alpha phase kubeconfig kubelet --config  kubeadm-master.yaml
#sudo systemctl start kubelet
#sudo kubeadm -v=8 alpha phase etcd local --config  kubeadm-master.yaml
#sudo kubeadm -v=8 alpha phase kubeconfig all --config  kubeadm-master.yaml
#sudo kubeadm -v=8 alpha phase controlplane all --config   kubeadm-master.yaml
#sudo kubeadm -v=8 alpha phase mark-master --config  kubeadm-master.yaml

# task to integrate in kolt

# 1. create all correct keys with kolt
# 2. create admin keys and embed them in admin.conf

#  The “admin” here is defined the actual person(s) that is administering
#  the cluster and want to have full control (root) over the cluster.
#  The embedded client certificate for admin should: -
#  Be in the system:masters organization, as defined by default RBAC user
#  facing role bindings - Include a CN, but that can be anything.
#  Kubeadm uses the kubernetes-admin CN

#  O=system:masters CN=kuberenetes-admin

curl -q https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml > /etc/kubernetes/rbac-kdd.yaml
curl -q https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml > /etc/kubernetes/calico.yaml
sed -i 's/"192.168.0.0\/16"/${POD_SUBNET}\/${POD_SUBNETMASK}/' /etc/kubernetes/calico.yaml

sudo kubeadm init --config=/etc/kubernetes/kubeadm-master.yaml
#sudo kubectl apply -f rbac-kdd.yaml --kubeconfig=/etc/kubernetes/admin.conf
#sudo kubectl apply -f calico.yaml --kubeconfig=/etc/kubernetes/admin.conf

#sudo kubeadm -v=8 alpha phase addon kube-proxy --config  kubeadm-master.yaml
#sudo kubeadm -v=8 alpha phase addon coredns --config  kubeadm-master.yaml
#sudo kubeadm alpha phase bootstrap-token all --token ${BOOTSTRAP_TOKEN}

# discoverHash:
# sha256:fe3c078b230624ec2297133933314b9a2821fa12c80226957ea716546d0cc1a9
