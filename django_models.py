###############################################################
# Servers
###############################################################

class ServerType(models.Model):
    name       = models.CharField(max_length=40, verbose_name='Nome')
    type       = models.CharField(max_length=40, verbose_name='Tipo')
    created_at = models.DateTimeField(auto_now=False, auto_now_add=True, verbose_name='Created')
    updated_at = models.DateTimeField(auto_now=True, verbose_name='Updated')
    expire_at  = models.DateTimeField(null=True, verbose_name='Expires')
    author     = models.CharField(max_length=40, null=True)

    class Meta:
        verbose_name_plural = 'Servers - Models'
        verbose_name        = 'Server - Model'

    def __unicode__(self):
        return self.name

class Servers(models.Model):
    STATUS_CHOICES = (
        ('outdated', 'Outdated'),
        ('dev',      'Development'),
        ('stolen',   'Stolen'),
        ('maint',    'Maintenance'),
        ('off',      'Offline'),
        ('on',       'Online'),
        ('stock',    'Stocked'),
    )
    name       = models.CharField(max_length=40, verbose_name='Name', unique=True)
    type       = models.ForeignKey(ServerType)
    list       = models.CharField(db_index=True, null=True, blank=True, max_length=200, help_text='IP/Name (space separated)', verbose_name="Host")
    status     = models.CharField(max_length=11, choices=STATUS_CHOICES, verbose_name='Status', help_text='Status', default='on')
    mac        = models.CharField(db_index=True, max_length=20, default='auto', verbose_name='Mac Address', blank=True, null=True)
    puppet_at  = models.DateTimeField(null=True, verbose_name='Last Puppet Run')
    created_at = models.DateTimeField(auto_now=False, auto_now_add=True, verbose_name='Created')
    updated_at = models.DateTimeField(auto_now=True, verbose_name='Updated')
    expire_at  = models.DateTimeField(null=True, verbose_name='Expires')
    author     = models.CharField(max_length=40, null=True)

    class Meta:
        verbose_name_plural = 'Servers'
        verbose_name        = 'Server'

    def __unicode__(self):
        return self.name


###############################################################
# Puppet
###############################################################

class PuppetModule(models.Model):
    module     = models.CharField(max_length=40, verbose_name='Module', unique=True)
    obs        = models.CharField(max_length=80, verbose_name='Description')
    filtro     = models.TextField(help_text='(CSV Regular Expression HOSTNAME). Ex. "saltop.*, fremontt\d{2}", "saltop*, !saltop01", ".*, !saltop01"', verbose_name='Filter', blank=True, null=True)
    created_at = models.DateTimeField(auto_now=False, auto_now_add=True, verbose_name='Created')
    updated_at = models.DateTimeField(auto_now=True, verbose_name='Updated')
    expire_at  = models.DateTimeField(null=True, blank=True, verbose_name='Expires')
    author     = models.CharField(max_length=40, null=True)

    class Meta:
        verbose_name_plural = 'Puppet Models'
        verbose_name        = 'Puppet Model'

    def __unicode__(self):
        return self.module

class PuppetClass(models.Model):
    name       = models.CharField(max_length=40, verbose_name='Nome', unique=True)
    servertype = models.ManyToManyField(ServerType, verbose_name='Groups', help_text='Grupos ao qual tem acesso.')
    modules    = models.ManyToManyField(PuppetModule, verbose_name='Models', help_text='Models', blank=True, null=True)
    created_at = models.DateTimeField(auto_now=False, auto_now_add=True, verbose_name='Created')
    updated_at = models.DateTimeField(auto_now=True, verbose_name='Updated')
    expire_at  = models.DateTimeField(null=True, blank=True, verbose_name='Expires')
    author     = models.CharField(max_length=40, null=True)

    class Meta:
        verbose_name_plural = 'Puppet Classes'
        verbose_name        = 'Puppet Class'

    def __unicode__(self):
        return self.name
