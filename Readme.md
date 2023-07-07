Set all environment variables in the Dockerfile.

Add your benchmark file into the benchmark folder of the project (at the moment it's only accepting cmd_set and cmd_get names for the files).

`docker build -t mc-crusher-horreum .`

`docker run -it --name mc-crusher-horreum -d mc-crusher-horreum`

Run the script mc-crusher.pl with timeout time in seconds as the first argument, example:

`docker exec -it mc-crusher-horreum /mc-crusher/mc-crusher.pl 10`

The script will run for 10 seconds and then exit sending the results to the Horreum server.

