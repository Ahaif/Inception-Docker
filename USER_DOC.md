# User documentation

How to use
- Set `LOGIN` in `srcs/.env` to your username.
- Copy the workspace into your virtual machine.
- In the VM run:

```sh
cd /path/to/inception
make all
```

Access
- Open a browser and visit `https://<your-vm-ip>` (accept the self-signed certificate).
- WordPress admin is available at `https://<your-vm-ip>/wp-admin`.

Notes
- The nginx container is the only public entrypoint on port 443.
