# Existing assets

This document is a short overview of the assets currently stored in the NFS mount. On integration the sizes of the directories under `/mnt/uploads` are:

``` bash
@integration-asset-master-1:~$ cd /mnt/uploads/
@integration-asset-master-1:/mnt/uploads$ du -h --max-depth=1
35G ./asset-manager
629G    ./whitehall
7.6M    ./publisher
14G ./support-api
16K ./lost+found
677G    .
```

Comparing this to the [production Grafana dashboard](https://grafana.publishing.service.gov.uk/dashboard/db/assets) (674.99G today) leads me to believe that integration has all of the assets that are on production.

The asset manager application stores a record in MongoDB for each asset. On integration the number of records is

``` bash
@integration-backend-1:/var/apps/asset-manager$ sudo su - deploy
deploy@integration-backend-1:~$ cd /var/apps/asset-manager
deploy@integration-backend-1:/var/apps/asset-manager$ govuk_setenv asset-manager bundle exec rails c
Loading production environment (Rails 4.2.7.1)
irb(main):002:0> Asset.count
=> 57232
```

We generate a list of all the files stored in NFS in the asset manager directory

``` bash
@integration-asset-master-1:/mnt/uploads/asset-manager$ find . -type f | xargs ls -s > ~/file_sizes.txt
```

This indicates that there are 58,613 files in the NFS mount (which is slightly more than the number of records in MongoDB).

``` bash
12:18 $ wc -l file_sizes.txt
   58613 file_sizes.txt
```

I haven't investigated yet why this difference exists. However we can take a look at the file sizes of the files on the mount

``` bash
cat file_sizes.txt | tr -d ' ' | awk -F"[.]/" '{print $1","$2}
```

Loading this file into R allows us to calculate the distribution of file sizes

``` r
library(readr)
d <- read_csv('file_sizes.csv', col_names=c('size', 'filename'))
quantile(d$size, c(.5, .8, .95, .99, 1))
```

```
   50%       80%       95%       99%      100%
204.00    732.00   2376.00   6031.52 174844.00
```

The median file size is 204k, 95% of all assets are under 2.3Mb and the largest asset is just over 174Mb.