## Aliyun Console
Better visualization of resources on the cloud.

### View: VPC, Subnets and Zones
![sample-vpc-subnet-zone-view](https://raw.githubusercontent.com/changbowen/Misc/master/aliyun-console/sample-vpc-subnet-zone-view.png)

- Table view of instances (ECS, RDS ...) in the target region.
- Resources are placed into columns of zones.
- Row name is a joined name of all the similar vSwitche names. Similar means **same** before the last hyphen (-). This view works well if you keep your vSwitch names in the format: XXXXXXXX-A, XXXXXXXX-E, XXXXXXXX-F... where the last letter is the ending letter of the zone ID.
- Instance panel (tooltip) with more details is shown when clicking on the instance block.
- Colorized background indicating the status of the instances (running, stopped, charge type...).
- ...

### View: VPC, Subnets
- Similar to the previous view, but without joining of the vSwitch names.
