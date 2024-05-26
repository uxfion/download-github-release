
```
sudo apt update
sudo apt install -y curl jq
```

```
curl -L https://github.com/uxfion/.config/raw/main/bin/download_github_release.sh
curl https://raw.githubusercontent.com/uxfion/.config/main/bin/download_github_release.sh > download_github_release.sh


# 不行，因为包含了检测source
# BASH_SOURCE[0]:
# 0: bash
curl https://raw.githubusercontent.com/uxfion/.config/main/bin/download_github_release.sh | bash  
curl https://raw.githubusercontent.com/uxfion/.config/main/bin/download_github_release.sh | bash -s -- sharkdp/bat ./ linux x86 musl


# 正常
bash <(curl https://raw.githubusercontent.com/uxfion/.config/main/bin/download_github_release.sh) sharkdp/bat ./ linux x86 mus


```