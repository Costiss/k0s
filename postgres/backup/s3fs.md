```bash
sudo apt install s3fs

# LOCALLY
echo ACCESS_KEY:SECRET_KEY > ~/.passwd-s3fs
chmod 600 ~/.passwd-s3fs
# GLABALLY
sudo tee /etc/passwd-s3fs <<< "ACCESS_KEY:SECRET_KEY"
sudo chmod 600 /etc/passwd-s3fs


s3fs BUCKET_NAME ~/.bucket-path -o passwd_file=~/.passwd-s3fs  -o url=https://endpoint
```
