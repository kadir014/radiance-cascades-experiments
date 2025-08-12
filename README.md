# radiance-cascades-experiments
Radiance Cascades is a pretty recent technique for noiseless global illumination.

This technique has been created and still improving by a group of awesome folks (they even have a discord server!). This repo is just me researching the topic, implementing and experimenting stuff on my own...



# Running
You need Python 3.10+. After cloning the repo, install required packages:
```sh
$ python -m pip install -r requirements.txt
```
And then just run `main.py`. You can edit `src/common.py` to adjust common settings.
```sh
$ python main.py
```


# Resources & References
Amazing resources that this project could have not been possible without:
- [WIP Radiance Cascades Paper](https://drive.google.com/file/d/1L6v1_7HY2X-LV3Ofb6oyTIxgEaP4LOI6/view)
- [Building Real-Time Global Illumination by Jason McGhee](https://jason.today/gi)
- [Radiance Cascades Playground by tmpvar](https://tmpvar.com/poc/radiance-cascades/)



# License
[MIT](LICENSE) © Kadir Aksoy