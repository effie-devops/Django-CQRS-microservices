from django.db import models

class Library(models.Model):
    title = models.CharField(max_length=200)
    author = models.CharField(max_length=200)
    description = models.TextField()

    class Meta:
        db_table = 'writer_library'

    def __str__(self):
        return self.title